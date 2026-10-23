#import "DmSaveFolderSync.h"
#import <CommonCrypto/CommonDigest.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

NSString * const DmSaveFolderSyncNotice = @"DmSaveFolderSyncNotice";
static NSString * const kBookmark = @"DmSaveFolderSync.bookmark";
static NSString * const kMode = @"DmSaveFolderSync.mode";
static NSString * const kEnabled = @"DmSaveFolderSync.enabled";
static NSString * const kLocalFingerprint = @"DmSaveFolderSync.localFingerprint";
static NSString * const kExternalFingerprint = @"DmSaveFolderSync.externalFingerprint";
static NSString * const kLastSync = @"DmSaveFolderSync.lastSync";

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
@end

@implementation DmSaveFolderSync

static BOOL validTitleID(NSString *titleID) {
    if (titleID.length != 16) return NO;
    NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    return [[titleID stringByTrimmingCharactersInSet:hex] length] == 0;
}

- (instancetype)initWithLocalSave:(NSURL *)localSave titleID:(NSString *)titleID {
    if (!(self = [super init])) return nil;
    _localSave = localSave; _titleID = [titleID copy];
    _queue = [NSOperationQueue new]; _queue.maxConcurrentOperationCount = 1;
    _mode = [NSUserDefaults.standardUserDefaults integerForKey:kMode];
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
- (void)setMode:(DmSaveFolderSyncMode)mode { _mode = mode; [NSUserDefaults.standardUserDefaults setInteger:mode forKey:kMode]; }
- (void)setEnabled:(BOOL)enabled { _enabled = enabled; [NSUserDefaults.standardUserDefaults setBool:enabled forKey:kEnabled]; }

- (void)resolveBookmark {
    NSData *data = [NSUserDefaults.standardUserDefaults dataForKey:kBookmark];
    if (!data) return;
    BOOL stale = NO; NSError *error = nil;
    NSURL *url = [NSURL URLByResolvingBookmarkData:data options:(NSURLBookmarkResolutionWithoutUI | NSURLBookmarkResolutionWithoutMounting)
                                      relativeToURL:nil bookmarkDataIsStale:&stale error:&error];
    if (!url || ![url startAccessingSecurityScopedResource]) {
        [self notice:@"Selected folder is unavailable; choose it again" state:DmSaveFolderSyncStateUnavailable]; return;
    }
    if (stale) {
        NSData *fresh = [url bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
        if (fresh) [NSUserDefaults.standardUserDefaults setObject:fresh forKey:kBookmark];
    }
    _selectedFolder = url; _selectedFolderName = url.lastPathComponent ?: url.path;
    _state = DmSaveFolderSyncStateReady; _statusText = @"Ready";
}

- (NSURL *)gameFolder { return [self.selectedFolder URLByAppendingPathComponent:self.titleID isDirectory:YES]; }
- (BOOL)hasData:(NSURL *)url {
    NSArray *items = [NSFileManager.defaultManager contentsOfDirectoryAtURL:url includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    return items.count != 0;
}
- (NSString *)fingerprint:(NSURL *)url {
    if (![self hasData:url]) return @"empty";
    NSMutableData *manifest = [NSMutableData data]; NSFileManager *fm = NSFileManager.defaultManager;
    NSDirectoryEnumerator *e = [fm enumeratorAtURL:url includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLFileSizeKey]
                         options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^BOOL(NSURL *u, NSError *err) { return YES; }];
    for (NSURL *item in e) {
        NSNumber *dir = nil; [item getResourceValue:&dir forKey:NSURLIsDirectoryKey error:nil]; if (dir.boolValue) continue;
        NSData *contents = [NSData dataWithContentsOfURL:item options:NSDataReadingMappedIfSafe error:nil]; if (!contents) return nil;
        unsigned char digest[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(contents.bytes, (CC_LONG)contents.length, digest);
        NSString *relative = [item.path substringFromIndex:url.path.length];
        while ([relative hasPrefix:@"/"]) relative = [relative substringFromIndex:1];
        [manifest appendData:[relative dataUsingEncoding:NSUTF8StringEncoding]]; [manifest appendBytes:digest length:sizeof digest];
    }
    unsigned char digest[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(manifest.bytes, (CC_LONG)manifest.length, digest);
    NSMutableString *out = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2]; for (NSUInteger i = 0; i < sizeof digest; i++) [out appendFormat:@"%02x", digest[i]]; return out;
}
- (BOOL)copyTree:(NSURL *)source to:(NSURL *)destination error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm createDirectoryAtURL:destination withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    NSDirectoryEnumerator *e = [fm enumeratorAtURL:source includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^BOOL(NSURL *u, NSError *err) { if (error) *error = err; return NO; }];
    for (NSURL *item in e) {
        NSString *rel = [item.path substringFromIndex:source.path.length]; while ([rel hasPrefix:@"/"]) rel = [rel substringFromIndex:1]; NSURL *target = [destination URLByAppendingPathComponent:rel]; NSNumber *dir = nil; [item getResourceValue:&dir forKey:NSURLIsDirectoryKey error:error];
        if (dir.boolValue) { if (![fm createDirectoryAtURL:target withIntermediateDirectories:YES attributes:nil error:error]) return NO; }
        else { if (![fm copyItemAtURL:item toURL:target error:error]) return NO; }
    }
    return YES;
}
- (BOOL)replaceTree:(NSURL *)source destination:(NSURL *)destination error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager; NSURL *stage = [destination URLByAppendingPathExtension:[NSString stringWithFormat:@"stage-%@", NSUUID.UUID.UUIDString]];
    if (![self copyTree:source to:stage error:error]) { [fm removeItemAtURL:stage error:nil]; return NO; }
    NSURL *old = [destination URLByAppendingPathExtension:[NSString stringWithFormat:@"old-%@", NSUUID.UUID.UUIDString]];
    if ([fm fileExistsAtPath:destination.path] && ![fm moveItemAtURL:destination toURL:old error:error]) { [fm removeItemAtURL:stage error:nil]; return NO; }
    if (![fm moveItemAtURL:stage toURL:destination error:error]) { if ([fm fileExistsAtPath:old.path]) [fm moveItemAtURL:old toURL:destination error:nil]; return NO; }
    [fm removeItemAtURL:old error:nil]; return YES;
}
- (void)syncOnQueue:(BOOL)manual {
    if (!self.enabled || !self.selectedFolder || self.syncing) return; self.syncing = YES;
    [self.selectedFolder startAccessingSecurityScopedResource]; NSURL *external = [self gameFolder]; NSError *error = nil;
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil]; __block BOOL ok = YES;
    [coordinator coordinateReadingItemAtURL:external options:0 error:&error byAccessor:^(NSURL *u) { (void)u; }];
    NSString *localFP = [self fingerprint:self.localSave], *externalFP = [self fingerprint:external];
    BOOL local = localFP && ![localFP isEqualToString:@"empty"], ext = externalFP && ![externalFP isEqualToString:@"empty"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:external.path] && local) {
        [self notice:@"Game folder is missing; confirm creation in Resolve Conflicts" state:DmSaveFolderSyncStateNeedsResolution]; self.syncing = NO; return;
    }
    NSString *knownLocal = [NSUserDefaults.standardUserDefaults stringForKey:kLocalFingerprint], *knownExternal = [NSUserDefaults.standardUserDefaults stringForKey:kExternalFingerprint];
    if (local && ext && ![localFP isEqualToString:externalFP] && (!knownLocal || !knownExternal || (![localFP isEqualToString:knownLocal] && ![externalFP isEqualToString:knownExternal]))) {
        NSURL *recovery = [self.localSave.URLByDeletingLastPathComponent URLByAppendingPathComponent:@"SaveFolderSync-Recovery" isDirectory:YES];
        recovery = [recovery URLByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", self.titleID, NSUUID.UUID.UUIDString] isDirectory:YES];
        [self copyTree:self.localSave to:[recovery URLByAppendingPathComponent:@"local" isDirectory:YES] error:nil];
        [self notice:@"Local and external saves both changed; resolve the conflict" state:DmSaveFolderSyncStateNeedsResolution]; self.syncing = NO; return;
    }
    BOOL shouldImport = ext && !local; if (!shouldImport && local && (!ext || [localFP isEqualToString:knownLocal])) shouldImport = ext && knownLocal && ![externalFP isEqualToString:knownExternal];
    if (shouldImport) ok = [self replaceTree:external destination:self.localSave error:&error];
    else if (local && (!ext || [localFP isEqualToString:knownExternal])) {
        NSURL *stage = [external URLByAppendingPathExtension:[NSString stringWithFormat:@"incoming-%@", NSUUID.UUID.UUIDString]];
        ok = [self copyTree:self.localSave to:stage error:&error];
        if (ok) { [NSFileManager.defaultManager removeItemAtURL:external error:nil]; ok = [NSFileManager.defaultManager moveItemAtURL:stage toURL:external error:&error]; }
    }
    if (ok) {
        NSString *l = [self fingerprint:self.localSave], *x = [self fingerprint:external]; [NSUserDefaults.standardUserDefaults setObject:l forKey:kLocalFingerprint]; [NSUserDefaults.standardUserDefaults setObject:x forKey:kExternalFingerprint]; self.lastSuccessfulSync = NSDate.date; [NSUserDefaults.standardUserDefaults setObject:self.lastSuccessfulSync forKey:kLastSync]; [self notice:manual ? @"Save folder synchronized" : @"Save folder ready" state:DmSaveFolderSyncStateReady];
    } else [self notice:error.localizedDescription ?: @"Save folder is unavailable; local save preserved" state:DmSaveFolderSyncStateError];
    self.syncing = NO;
}
- (void)startBeforeGameplay { if (self.enabled) [self resumeSafely]; }
- (void)resumeSafely { if (!self.enabled || !self.selectedFolder) return; [self.queue addOperationWithBlock:^{ [self syncOnQueue:NO]; }]; }
- (void)saveCommitted { if (!self.enabled || !self.selectedFolder) return; [self.queue addOperationWithBlock:^{ [self syncOnQueue:NO]; }]; }
- (void)syncNow { [self.queue addOperationWithBlock:^{ [self syncOnQueue:YES]; }]; }

- (void)presentFolderPickerFromViewController:(UIViewController *)viewController {
    self.pickerPresenter = viewController; UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType typeWithIdentifier:@"public.folder"]] asCopy:NO];
    picker.delegate = self; picker.allowsMultipleSelection = NO; [viewController presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject; if (!url || ![url startAccessingSecurityScopedResource]) { [self notice:@"Could not access that folder" state:DmSaveFolderSyncStateUnavailable]; return; }
    NSData *bookmark = [url bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
    if (!bookmark) { [self notice:@"Could not persist access to that folder" state:DmSaveFolderSyncStateError]; return; }
    [NSUserDefaults.standardUserDefaults setObject:bookmark forKey:kBookmark]; _selectedFolder = url; _selectedFolderName = url.lastPathComponent ?: url.path; self.state = DmSaveFolderSyncStateReady; self.statusText = @"Folder selected";
    if (self.enabled) [self syncNow];
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller { (void)controller; }
- (void)resolveByImportingExternal { self.enabled = NO; [self.queue addOperationWithBlock:^{ NSError *e = nil; BOOL ok = [self replaceTree:[self gameFolder] destination:self.localSave error:&e]; self.enabled = YES; if (ok) [self syncOnQueue:YES]; else [self notice:e.localizedDescription ?: @"External save could not be imported" state:DmSaveFolderSyncStateError]; }]; }
- (void)resolveByExportingLocal { self.enabled = NO; [self.queue addOperationWithBlock:^{ NSError *e = nil; NSURL *external = [self gameFolder]; NSURL *stage = [external URLByAppendingPathExtension:[NSString stringWithFormat:@"incoming-%@", NSUUID.UUID.UUIDString]]; BOOL ok = [self copyTree:self.localSave to:stage error:&e]; if (ok) { [NSFileManager.defaultManager removeItemAtURL:external error:nil]; ok = [NSFileManager.defaultManager moveItemAtURL:stage toURL:external error:&e]; } self.enabled = YES; if (ok) [self syncOnQueue:YES]; else [self notice:e.localizedDescription ?: @"Local save could not be exported" state:DmSaveFolderSyncStateError]; }]; }
- (void)preserveBoth { [self notice:@"Both saves preserved; synchronization remains disabled" state:DmSaveFolderSyncStateNeedsResolution]; self.enabled = NO; }
@end
