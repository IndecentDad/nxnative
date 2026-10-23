#import "DmSaveFolderSync.h"
#import <CommonCrypto/CommonDigest.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

NSString * const DmSaveFolderSyncNotice = @"DmSaveFolderSyncNotice";
static NSString * const kBookmark = @"DmSaveFolderSync.bookmark";
static NSString * const kEnabled = @"DmSaveFolderSync.enabled";
static NSString * const kLocalFingerprint = @"DmSaveFolderSync.localFingerprint";
static NSString * const kExternalFingerprint = @"DmSaveFolderSync.externalFingerprint";
static NSString * const kLastSync = @"DmSaveFolderSync.lastSync";
static NSUInteger const kRecoverySnapshotLimit = 3;

@interface DmSaveFolderSync ()
@property(nonatomic,strong) NSURL *localSave;
@property(nonatomic,copy) NSString *titleID;
@property(nonatomic,strong) NSURL *selectedFolder;
@property(nonatomic,copy) NSString *selectedFolderName;
@property(nonatomic,copy) NSString *statusText;
@property(nonatomic,strong) NSDate *lastSuccessfulSync;
@property(nonatomic) DmSaveFolderSyncState state;
@property(nonatomic,strong) NSOperationQueue *queue;
@property(nonatomic,weak) UIViewController *pickerPresenter;
@property(nonatomic) BOOL syncing;
@property(nonatomic) BOOL restartRequired;
@property(nonatomic) BOOL securityScopeActive;
@end

@implementation DmSaveFolderSync

static BOOL validTitleID(NSString *titleID) {
    if (titleID.length != 16) return NO;
    NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    return [[titleID stringByTrimmingCharactersInSet:hex] length] == 0;
}

- (instancetype)initWithLocalSave:(NSURL *)localSave titleID:(NSString *)titleID {
    if (!(self = [super init])) return nil;
    _localSave = localSave; _titleID = [titleID uppercaseString];
    _queue = [NSOperationQueue new]; _queue.maxConcurrentOperationCount = 1;
    _enabled = [NSUserDefaults.standardUserDefaults boolForKey:kEnabled];
    _lastSuccessfulSync = [NSUserDefaults.standardUserDefaults objectForKey:kLastSync];
    _state = DmSaveFolderSyncStateUnconfigured; _statusText = @"No folder selected";
    if (!validTitleID(_titleID)) { _state = DmSaveFolderSyncStateError; _statusText = @"Invalid game title ID"; return self; }
    [self resolveBookmark];
    return self;
}

- (void)notice:(NSString *)message state:(DmSaveFolderSyncState)state {
    self.statusText = message; self.state = state;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DmSaveFolderSyncNotice object:message];
    });
}
- (void)setEnabled:(BOOL)enabled { _enabled = enabled; [NSUserDefaults.standardUserDefaults setBool:enabled forKey:kEnabled]; }

- (void)resolveBookmark {
    NSData *data = [NSUserDefaults.standardUserDefaults dataForKey:kBookmark];
    if (!data) return;
    BOOL stale = NO; NSError *error = nil;
    NSURL *url = [NSURL URLByResolvingBookmarkData:data options:(NSURLBookmarkResolutionWithoutUI | NSURLBookmarkResolutionWithoutMounting)
                                      relativeToURL:nil bookmarkDataIsStale:&stale error:&error];
    if (!url || ![url startAccessingSecurityScopedResource]) {
        self.enabled = NO;
        [self notice:@"Selected folder is unavailable; choose it again" state:DmSaveFolderSyncStateUnavailable]; return;
    }
    if (stale) {
        NSData *fresh = [url bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
        if (fresh) [NSUserDefaults.standardUserDefaults setObject:fresh forKey:kBookmark];
    }
    _selectedFolder = url; _selectedFolderName = url.lastPathComponent ?: url.path; _securityScopeActive = YES;
    _state = DmSaveFolderSyncStateReady; _statusText = @"Ready";
}

- (NSURL *)localPayloadURL { return self.localSave; }
- (NSURL *)externalPayloadURL {
    // The picker selects a shared root; only the current title ID is appended.
    return [self.selectedFolder URLByAppendingPathComponent:self.titleID isDirectory:YES];
}
- (NSURL *)gameFolder { return [self externalPayloadURL]; }
- (BOOL)isReservedPayloadComponent:(NSString *)name {
    return [name isEqualToString:@"SaveFolderSync-Recovery"] ||
           [name hasPrefix:@".stage-"] || [name hasPrefix:@".incoming-"] || [name hasPrefix:@".old-"];
}
- (BOOL)hasData:(NSURL *)url {
    for (NSURL *item in [NSFileManager.defaultManager contentsOfDirectoryAtURL:url includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil])
        if (![self isReservedPayloadComponent:item.lastPathComponent]) return YES;
    return NO;
}
- (NSString *)fingerprint:(NSURL *)url { return [self fingerprint:url error:nil]; }
- (NSString *)fingerprint:(NSURL *)url error:(NSError **)error {
    BOOL directory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path isDirectory:&directory]) return @"empty";
    if (!directory) {
        if (error) *error = [NSError errorWithDomain:@"DmSaveFolderSync" code:16 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Save path is not a directory: %@", url.lastPathComponent ?: url.path]}];
        return nil;
    }
    if (![self hasData:url]) return @"empty";
    NSMutableData *manifest = [NSMutableData data]; NSMutableArray<NSDictionary *> *entries = [NSMutableArray array]; NSFileManager *fm = NSFileManager.defaultManager;
    __block NSError *scanError = nil;
    NSDirectoryEnumerator *e = [fm enumeratorAtURL:url includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsUbiquitousItemKey, NSURLUbiquitousItemIsDownloadedKey]
                         options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^BOOL(NSURL *u, NSError *err) { scanError = err; return NO; }];
    for (NSURL *item in e) {
        NSError *resourceError = nil; NSNumber *dir = nil;
        if (![item getResourceValue:&dir forKey:NSURLIsDirectoryKey error:&resourceError]) { scanError = resourceError; break; }
        if ([self isReservedPayloadComponent:item.lastPathComponent]) { if (dir.boolValue) [e skipDescendants]; continue; }
        if (dir.boolValue) continue;
        NSNumber *ubiquitous = nil, *downloaded = nil;
        [item getResourceValue:&ubiquitous forKey:NSURLIsUbiquitousItemKey error:&resourceError];
        [item getResourceValue:&downloaded forKey:NSURLUbiquitousItemIsDownloadedKey error:&resourceError];
        if (ubiquitous.boolValue && !downloaded.boolValue) { scanError = [NSError errorWithDomain:@"DmSaveFolderSync" code:11 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Save file is present but not downloaded: %@", item.lastPathComponent]}]; break; }
        NSData *contents = [[NSData alloc] initWithContentsOfURL:item options:NSDataReadingMappedIfSafe error:&resourceError];
        if (!contents) { scanError = [NSError errorWithDomain:@"DmSaveFolderSync" code:17 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Save file is missing or unreadable: %@%@", item.lastPathComponent, resourceError.localizedDescription.length ? [NSString stringWithFormat:@" (%@)", resourceError.localizedDescription] : @""]}]; break; }
        unsigned char digest[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(contents.bytes, (CC_LONG)contents.length, digest);
        NSString *relative = [item.path substringFromIndex:url.path.length];
        while ([relative hasPrefix:@"/"]) relative = [relative substringFromIndex:1];
        [entries addObject:@{ @"path": relative, @"digest": [NSData dataWithBytes:digest length:sizeof digest] }];
    }
    if (scanError) { if (error) *error = scanError; return nil; }
    [entries sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [a[@"path"] compare:b[@"path"]]; }];
    for (NSDictionary *entry in entries) { [manifest appendData:[entry[@"path"] dataUsingEncoding:NSUTF8StringEncoding]]; [manifest appendData:entry[@"digest"]]; }
    unsigned char digest[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(manifest.bytes, (CC_LONG)manifest.length, digest);
    NSMutableString *out = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2]; for (NSUInteger i = 0; i < sizeof digest; i++) [out appendFormat:@"%02x", digest[i]]; return out;
}
- (NSUInteger)payloadFileCount:(NSURL *)url {
    NSUInteger count = 0; NSDirectoryEnumerator *e = [NSFileManager.defaultManager enumeratorAtURL:url includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^BOOL(NSURL *u, NSError *err) { return YES; }];
    for (NSURL *item in e) {
        NSNumber *directory = nil; [item getResourceValue:&directory forKey:NSURLIsDirectoryKey error:nil];
        if ([self isReservedPayloadComponent:item.lastPathComponent]) { if (directory.boolValue) [e skipDescendants]; continue; }
        if (!directory.boolValue) count++;
    }
    return count;
}
- (BOOL)copyTree:(NSURL *)source to:(NSURL *)destination error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    if (![fm fileExistsAtPath:source.path isDirectory:&isDirectory] || !isDirectory) {
        if (error) *error = [NSError errorWithDomain:@"DmSaveFolderSync" code:10 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Source save directory does not exist: %@", source.lastPathComponent ?: source.path]}];
        return NO;
    }
    if (![fm createDirectoryAtURL:destination withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    NSDirectoryEnumerator *e = [fm enumeratorAtURL:source includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsUbiquitousItemKey, NSURLUbiquitousItemIsDownloadedKey] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^BOOL(NSURL *u, NSError *err) { if (error) *error = err; return NO; }];
    for (NSURL *item in e) {
        NSError *resourceError = nil; NSNumber *reservedDir = nil;
        if (![item getResourceValue:&reservedDir forKey:NSURLIsDirectoryKey error:&resourceError]) { if (error) *error = resourceError; return NO; }
        if ([self isReservedPayloadComponent:item.lastPathComponent]) { if (reservedDir.boolValue) [e skipDescendants]; continue; }
        NSString *rel = [item.path substringFromIndex:source.path.length]; while ([rel hasPrefix:@"/"]) rel = [rel substringFromIndex:1]; NSURL *target = [destination URLByAppendingPathComponent:rel]; NSNumber *dir = reservedDir;
        if (dir.boolValue) { if (![fm createDirectoryAtURL:target withIntermediateDirectories:YES attributes:nil error:error]) return NO; }
        else {
            NSNumber *ubiquitous = nil, *downloaded = nil;
            [item getResourceValue:&ubiquitous forKey:NSURLIsUbiquitousItemKey error:&resourceError];
            [item getResourceValue:&downloaded forKey:NSURLUbiquitousItemIsDownloadedKey error:&resourceError];
            if (ubiquitous.boolValue && !downloaded.boolValue) {
                if (error) *error = [NSError errorWithDomain:@"DmSaveFolderSync" code:11 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Save file is present but not downloaded: %@", rel]}];
                return NO;
            }
            if (![fm copyItemAtURL:item toURL:target error:&resourceError]) {
                if (error) *error = [NSError errorWithDomain:@"DmSaveFolderSync" code:12 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not copy save file %@: %@", rel, resourceError.localizedDescription ?: @"unknown file error"]}];
                return NO;
            }
        }
    }
    return YES;
}
- (NSURL *)recoveryRoot {
    return [[[self localPayloadURL] URLByDeletingLastPathComponent] URLByAppendingPathComponent:[NSString stringWithFormat:@"SaveFolderSync-Recovery/%@", self.titleID] isDirectory:YES];
}
- (BOOL)makeRecoverySnapshotForLocal:(NSURL *)local external:(NSURL *)external localFingerprint:(NSString *)localFP externalFingerprint:(NSString *)externalFP error:(NSError **)error {
    if ((!localFP || [localFP isEqualToString:@"empty"]) && (!externalFP || [externalFP isEqualToString:@"empty"])) return YES;
    NSURL *root = [self recoveryRoot]; NSFileManager *fm = NSFileManager.defaultManager;
    NSArray *existing = [fm contentsOfDirectoryAtURL:root includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    NSUInteger snapshots = 0; for (NSURL *u in existing) if ([u.lastPathComponent hasPrefix:@"snapshot-"]) snapshots++;
    NSString *identifier = [NSString stringWithFormat:@"snapshot-%@-%@", localFP ?: @"empty", externalFP ?: @"empty"];
    NSURL *snapshot = [root URLByAppendingPathComponent:identifier isDirectory:YES];
    if ([fm fileExistsAtPath:snapshot.path] || snapshots >= kRecoverySnapshotLimit) return YES;
    if (![fm createDirectoryAtURL:root withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    NSURL *localCopy = [snapshot URLByAppendingPathComponent:@"local" isDirectory:YES];
    NSURL *externalCopy = [snapshot URLByAppendingPathComponent:@"external" isDirectory:YES];
    if ([self hasData:local] && ![self copyTree:local to:localCopy error:error]) return NO;
    if ([self hasData:external] && ![self copyTree:external to:externalCopy error:error]) return NO;
    return YES;
}
- (BOOL)replaceTree:(NSURL *)source destination:(NSURL *)destination error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager; NSURL *stage = [destination URLByAppendingPathExtension:[NSString stringWithFormat:@"stage-%@", NSUUID.UUID.UUIDString]];
    __block BOOL copied = NO; __block NSError *copyError = nil;
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    [coordinator coordinateReadingItemAtURL:source options:0 error:&copyError byAccessor:^(NSURL *u) { copied = [self copyTree:u to:stage error:&copyError]; }];
    if (!copied) { if (error) *error = copyError ?: [NSError errorWithDomain:@"DmSaveFolderSync" code:13 userInfo:@{NSLocalizedDescriptionKey: @"Could not read the source save files"}]; [fm removeItemAtURL:stage error:nil]; return NO; }
    NSURL *old = [destination URLByAppendingPathExtension:[NSString stringWithFormat:@"old-%@", NSUUID.UUID.UUIDString]];
    if ([fm fileExistsAtPath:destination.path] && ![fm moveItemAtURL:destination toURL:old error:error]) { [fm removeItemAtURL:stage error:nil]; return NO; }
    if (![fm moveItemAtURL:stage toURL:destination error:error]) { if ([fm fileExistsAtPath:old.path]) [fm moveItemAtURL:old toURL:destination error:nil]; return NO; }
    [fm removeItemAtURL:old error:nil]; return YES;
}
- (void)syncOnQueue:(BOOL)manual {
    if (!self.enabled || !self.selectedFolder || self.syncing) return; self.syncing = YES;
    if (!self.securityScopeActive && ![self.selectedFolder startAccessingSecurityScopedResource]) {
        [self notice:@"Selected folder is unavailable; choose it again" state:DmSaveFolderSyncStateUnavailable]; self.syncing = NO; return;
    }
    self.securityScopeActive = YES; NSURL *localPayload = [self localPayloadURL]; NSURL *external = [self externalPayloadURL]; NSError *error = nil; BOOL ok = YES;
    NSString *localFP = [self fingerprint:localPayload error:&error], *externalFP = [self fingerprint:external error:&error];
    if (!localFP || !externalFP) { [self notice:error.localizedDescription ?: @"Save files are unavailable; local save preserved" state:DmSaveFolderSyncStateError]; self.syncing = NO; return; }
    BOOL local = localFP && ![localFP isEqualToString:@"empty"], ext = externalFP && ![externalFP isEqualToString:@"empty"];
    NSString *knownLocal = [NSUserDefaults.standardUserDefaults stringForKey:kLocalFingerprint], *knownExternal = [NSUserDefaults.standardUserDefaults stringForKey:kExternalFingerprint];
    BOOL haveBaseline = knownLocal.length && knownExternal.length;
    BOOL localChanged = haveBaseline && ![localFP isEqualToString:knownLocal];
    BOOL externalChanged = haveBaseline && ![externalFP isEqualToString:knownExternal];
    if (local && ext && ![localFP isEqualToString:externalFP] && (!haveBaseline || (localChanged && externalChanged) || (!localChanged && !externalChanged))) {
        [self makeRecoverySnapshotForLocal:localPayload external:external localFingerprint:localFP externalFingerprint:externalFP error:nil];
        [self notice:@"Local and external saves both changed; resolve the conflict" state:DmSaveFolderSyncStateNeedsResolution]; self.syncing = NO; return;
    }
    BOOL shouldImport = ext && !local;
    if (local && ext && [localFP isEqualToString:externalFP]) shouldImport = NO;
    if (local && ext && externalChanged && !localChanged) shouldImport = YES;
    NSString *outcome = nil; NSUInteger transferred = 0;
    if (shouldImport) {
        transferred = [self payloadFileCount:external]; NSString *expected = externalFP;
        if (local && ![self makeRecoverySnapshotForLocal:localPayload external:external localFingerprint:localFP externalFingerprint:externalFP error:&error]) ok = NO;
        if (ok) ok = [self replaceTree:external destination:localPayload error:&error];
        NSString *sourceAfter = [self fingerprint:external];
        if (ok && ![sourceAfter isEqualToString:expected]) { error = [NSError errorWithDomain:@"DmSaveFolderSync" code:14 userInfo:@{NSLocalizedDescriptionKey: @"Source save changed or disappeared during import; local save preserved"}]; ok = NO; }
        if (ok && ![[self fingerprint:localPayload] isEqualToString:expected]) { error = [NSError errorWithDomain:@"DmSaveFolderSync" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Imported save verification failed; local save preserved"}]; ok = NO; }
        if (ok) { self.restartRequired = YES; outcome = [NSString stringWithFormat:@"Save files imported. Restart the game to load your updated saves. Avoid saving in-game before restarting. (%lu files)", (unsigned long)transferred]; }
    }
    else if (local && (!ext || localChanged)) {
        transferred = [self payloadFileCount:localPayload]; NSString *expected = localFP;
        NSURL *stage = [external URLByAppendingPathExtension:[NSString stringWithFormat:@"incoming-%@", NSUUID.UUID.UUIDString]];
        if (ext && ![localFP isEqualToString:externalFP]) ok = [self makeRecoverySnapshotForLocal:localPayload external:external localFingerprint:localFP externalFingerprint:externalFP error:&error];
        if (ok) ok = [self copyTree:localPayload to:stage error:&error];
        if (ok) {
            NSFileManager *fm = NSFileManager.defaultManager; NSURL *old = [external URLByAppendingPathExtension:[NSString stringWithFormat:@"old-%@", NSUUID.UUID.UUIDString]];
            if ([fm fileExistsAtPath:external.path] && ![fm moveItemAtURL:external toURL:old error:&error]) ok = NO;
            if (ok && ![fm moveItemAtURL:stage toURL:external error:&error]) { if ([fm fileExistsAtPath:old.path]) [fm moveItemAtURL:old toURL:external error:nil]; ok = NO; }
            [fm removeItemAtURL:old error:nil];
        }
        NSString *sourceAfter = [self fingerprint:localPayload];
        if (ok && ![sourceAfter isEqualToString:expected]) { error = [NSError errorWithDomain:@"DmSaveFolderSync" code:15 userInfo:@{NSLocalizedDescriptionKey: @"Device save changed during export; folder save preserved"}]; ok = NO; }
        if (ok && ![[self fingerprint:external] isEqualToString:expected]) { error = [NSError errorWithDomain:@"DmSaveFolderSync" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Exported save verification failed; folder save preserved"}]; ok = NO; }
        if (ok) outcome = [NSString stringWithFormat:@"Save files exported (%lu files).", (unsigned long)transferred];
    }
    else if (localFP && externalFP && [localFP isEqualToString:externalFP]) outcome = @"Already Up to Date";
    else if (!local && !ext) outcome = @"Already Up to Date";
    if (ok) {
        NSString *l = [self fingerprint:localPayload], *x = [self fingerprint:external]; [NSUserDefaults.standardUserDefaults setObject:l forKey:kLocalFingerprint]; [NSUserDefaults.standardUserDefaults setObject:x forKey:kExternalFingerprint]; self.lastSuccessfulSync = NSDate.date; [NSUserDefaults.standardUserDefaults setObject:self.lastSuccessfulSync forKey:kLastSync]; [self notice:outcome ?: (manual ? @"Already Up to Date" : @"Already Up to Date") state:DmSaveFolderSyncStateReady];
    } else [self notice:error.localizedDescription ?: @"Save folder is unavailable; local save preserved" state:DmSaveFolderSyncStateError];
    self.syncing = NO;
}
- (void)startBeforeGameplay {
    if (!self.enabled || !self.selectedFolder) return;
    BOOL hasLocalBaseline = [NSUserDefaults.standardUserDefaults stringForKey:kLocalFingerprint].length != 0;
    BOOL hasExternalBaseline = [NSUserDefaults.standardUserDefaults stringForKey:kExternalFingerprint].length != 0;
    if (!hasLocalBaseline || !hasExternalBaseline) [self syncOnQueue:NO];
    else [self resumeSafely];
}
- (void)resumeSafely { if (!self.enabled || !self.selectedFolder) return; [self.queue addOperationWithBlock:^{ [self syncOnQueue:NO]; }]; }
- (void)saveCommitted { if (!self.enabled || !self.selectedFolder || self.restartRequired) return; [self.queue addOperationWithBlock:^{ [self syncOnQueue:NO]; }]; }
- (void)syncNow {
    if (!self.enabled || !self.selectedFolder) return;
    [self notice:@"Syncing" state:DmSaveFolderSyncStateReady];
    [self.queue addOperationWithBlock:^{ [self syncOnQueue:YES]; }];
}

- (void)presentFolderPickerFromViewController:(UIViewController *)viewController {
    self.pickerPresenter = viewController; UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType typeWithIdentifier:@"public.folder"]] asCopy:NO];
    picker.delegate = self; picker.allowsMultipleSelection = NO; [viewController presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject; if (!url || ![url startAccessingSecurityScopedResource]) { [self notice:@"Could not access that folder" state:DmSaveFolderSyncStateUnavailable]; return; }
    NSData *bookmark = [url bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
    if (!bookmark) { [url stopAccessingSecurityScopedResource]; [self notice:@"Could not persist access to that folder" state:DmSaveFolderSyncStateError]; return; }
    if (self.selectedFolder && self.securityScopeActive) [self.selectedFolder stopAccessingSecurityScopedResource];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:kLocalFingerprint];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:kExternalFingerprint];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:kLastSync];
    self.lastSuccessfulSync = nil; self.restartRequired = NO;
    [NSUserDefaults.standardUserDefaults setObject:bookmark forKey:kBookmark]; _selectedFolder = url; _selectedFolderName = url.lastPathComponent ?: url.path; self.securityScopeActive = YES; self.state = DmSaveFolderSyncStateReady; self.statusText = @"Folder selected";
    self.enabled = YES;
    [self syncNow];
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller { (void)controller; }
- (void)clearSelectedFolder {
    if (self.selectedFolder && self.securityScopeActive) [self.selectedFolder stopAccessingSecurityScopedResource];
    self.securityScopeActive = NO;
    [NSUserDefaults.standardUserDefaults removeObjectForKey:kBookmark];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:kLocalFingerprint];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:kExternalFingerprint];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:kLastSync];
    self.selectedFolder = nil; self.selectedFolderName = nil; self.lastSuccessfulSync = nil;
    self.enabled = NO; self.state = DmSaveFolderSyncStateUnconfigured; self.statusText = @"No folder selected";
    [[NSNotificationCenter defaultCenter] postNotificationName:DmSaveFolderSyncNotice object:self.statusText];
}
- (void)resolveByImportingExternal {
    self.enabled = NO;
    [self.queue addOperationWithBlock:^{
        NSError *e = nil; NSURL *local = [self localPayloadURL], *external = [self externalPayloadURL];
        NSString *lf = [self fingerprint:local], *xf = [self fingerprint:external]; NSUInteger count = [self payloadFileCount:external];
        if (!xf || [xf isEqualToString:@"empty"]) { self.enabled = YES; [self notice:@"Folder contains no readable save files; local save preserved" state:DmSaveFolderSyncStateError]; return; }
        BOOL ok = [self makeRecoverySnapshotForLocal:local external:external localFingerprint:lf externalFingerprint:xf error:&e];
        if (ok) ok = [self replaceTree:external destination:local error:&e];
        if (ok && ![[self fingerprint:external] isEqualToString:xf]) { e = [NSError errorWithDomain:@"DmSaveFolderSync" code:14 userInfo:@{NSLocalizedDescriptionKey: @"Folder save changed or disappeared during import; local save preserved"}]; ok = NO; }
        if (ok && ![[self fingerprint:local] isEqualToString:xf]) { e = [NSError errorWithDomain:@"DmSaveFolderSync" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Folder save verification failed; local save preserved"}]; ok = NO; }
        self.enabled = YES;
        if (ok) {
            self.restartRequired = YES; [NSUserDefaults.standardUserDefaults setObject:xf forKey:kLocalFingerprint]; [NSUserDefaults.standardUserDefaults setObject:xf forKey:kExternalFingerprint]; self.lastSuccessfulSync = NSDate.date; [NSUserDefaults.standardUserDefaults setObject:self.lastSuccessfulSync forKey:kLastSync];
            [self notice:[NSString stringWithFormat:@"Save files imported. Restart the game to load your updated saves. Avoid saving in-game before restarting. (%lu files)", (unsigned long)count] state:DmSaveFolderSyncStateReady];
        } else [self notice:e.localizedDescription ?: @"Folder save import failed; local save preserved" state:DmSaveFolderSyncStateError];
    }];
}
- (void)resolveByExportingLocal {
    self.enabled = NO;
    [self.queue addOperationWithBlock:^{
        NSError *e = nil; NSURL *local = [self localPayloadURL], *external = [self externalPayloadURL];
        NSString *lf = [self fingerprint:local], *xf = [self fingerprint:external]; NSUInteger count = [self payloadFileCount:local];
        BOOL ok = (!xf || [xf isEqualToString:@"empty"] || [lf isEqualToString:xf]) ? YES : [self makeRecoverySnapshotForLocal:local external:external localFingerprint:lf externalFingerprint:xf error:&e];
        if (ok) ok = [self replaceTree:local destination:external error:&e];
        if (ok && ![[self fingerprint:local] isEqualToString:lf]) { e = [NSError errorWithDomain:@"DmSaveFolderSync" code:15 userInfo:@{NSLocalizedDescriptionKey: @"Device save changed during export; folder save preserved"}]; ok = NO; }
        if (ok && ![[self fingerprint:external] isEqualToString:lf]) { e = [NSError errorWithDomain:@"DmSaveFolderSync" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Device save verification failed; local save preserved"}]; ok = NO; }
        self.enabled = YES;
        if (ok) {
            [NSUserDefaults.standardUserDefaults setObject:lf forKey:kLocalFingerprint]; [NSUserDefaults.standardUserDefaults setObject:lf forKey:kExternalFingerprint]; self.lastSuccessfulSync = NSDate.date; [NSUserDefaults.standardUserDefaults setObject:self.lastSuccessfulSync forKey:kLastSync];
            [self notice:[NSString stringWithFormat:@"Save files exported (%lu files).", (unsigned long)count] state:DmSaveFolderSyncStateReady];
        } else [self notice:e.localizedDescription ?: @"Device save export failed; local save preserved" state:DmSaveFolderSyncStateError];
    }];
}
- (void)preserveBoth { [self notice:@"Both saves preserved; synchronization remains disabled" state:DmSaveFolderSyncStateNeedsResolution]; self.enabled = NO; }
@end
