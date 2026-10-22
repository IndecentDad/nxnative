#import "DmSaveSync.h"
#import <CommonCrypto/CommonDigest.h>
#import <sys/clonefile.h>
#include <stdio.h>
#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <sys/xattr.h>

static const char *kGuestNameXattr = "org.d2rmobile.guest-name";

@interface DmSaveSync ()
@property (nonatomic, strong) NSURL *documents, *state, *save;
@property (nonatomic, strong) NSURL *testCloudRoot;
@property (nonatomic, copy) NSString *titleID, *containerID, *lastStatus;
@property (nonatomic, strong) dispatch_queue_t queue;
@end

@implementation DmSaveSync

- (instancetype)initWithDocuments:(NSURL *)documents titleID:(NSString *)titleID containerID:(NSString *)containerID {
    if (!(self = [super init])) return nil;
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"] invertedSet];
    NSString *id16 = titleID.uppercaseString;
    if (id16.length != 16 || [id16 rangeOfCharacterFromSet:invalid].location != NSNotFound) return nil;
    _documents = documents; _save = [documents URLByAppendingPathComponent:@"save" isDirectory:YES];
    _state = [[documents URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"Library/Application Support/NXNativeSaveSync" isDirectory:YES];
    _titleID = id16; _containerID = [containerID copy]; _lastStatus = @"Not checked yet";
    _queue = dispatch_queue_create("org.nxnative.save-sync", DISPATCH_QUEUE_SERIAL);
    [NSFileManager.defaultManager createDirectoryAtURL:_state withIntermediateDirectories:YES attributes:nil error:nil];
    return self;
}
- (instancetype)initWithDocuments:(NSURL *)documents titleID:(NSString *)titleID testCloudRoot:(NSURL *)cloudRoot {
    self = [self initWithDocuments:documents titleID:titleID containerID:@"test"];
    if (self) _testCloudRoot = cloudRoot;
    return self;
}

- (NSString *)status { @synchronized (self) { return _lastStatus; } }
- (void)setStatus:(NSString *)status { @synchronized (self) { _lastStatus = status; } }
- (void)run:(NSString *(^)(void))task completion:(void (^)(NSString *))completion {
    dispatch_async(_queue, ^{ @autoreleasepool {
        NSString *result = task(); [self setStatus:result];
        fprintf(stderr, "save sync %s: %s\n", self.titleID.UTF8String, result.UTF8String);
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(result); });
    }});
}

- (NSURL *)metaURL { return [_state URLByAppendingPathComponent:[_titleID stringByAppendingString:@".plist"]]; }
- (NSDictionary *)baseline { return [NSDictionary dictionaryWithContentsOfURL:self.metaURL] ?: @{}; }
- (BOOL)saveBaseline:(NSDictionary *)entry {
    return [entry writeToURL:self.metaURL atomically:YES];
}
- (NSURL *)cloudRoot {
    if (_testCloudRoot) return [_testCloudRoot URLByAppendingPathComponent:_titleID isDirectory:YES];
    if (!_containerID.length) return nil;
    NSURL *container = [NSFileManager.defaultManager URLForUbiquityContainerIdentifier:_containerID];
    return [[container URLByAppendingPathComponent:@"Documents" isDirectory:YES]
            URLByAppendingPathComponent:[@"NXNative/Saves/" stringByAppendingString:_titleID] isDirectory:YES];
}
- (NSURL *)temporary:(NSString *)suffix {
    return [_state URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", NSUUID.UUID.UUIDString, suffix] isDirectory:YES];
}

// Hash path names and bytes, with explicit lengths, in sorted order. Reject links
// and nonregular entries so an imported archive cannot reach outside its snapshot.
- (NSString *)hashTree:(NSURL *)tree error:(NSError **)error {
    char canonical[PATH_MAX];
    if (realpath(tree.fileSystemRepresentation, canonical)) tree = [NSURL fileURLWithPath:@(canonical) isDirectory:YES];
    NSFileManager *fm = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    if (![fm fileExistsAtPath:tree.path isDirectory:&isDirectory] || !isDirectory) {
        if (error) *error = [NSError errorWithDomain:@"DmSaveSync" code:3 userInfo:@{NSLocalizedDescriptionKey:@"Save directory is missing"}];
        return nil;
    }
    __block NSError *scanError = nil;
    NSDirectoryEnumerator *en = [fm enumeratorAtURL:tree includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsRegularFileKey, NSURLIsSymbolicLinkKey]
                                         options:0 errorHandler:^BOOL(NSURL *url, NSError *e) { (void)url; scanError = e; return NO; }];
    NSMutableArray<NSString *> *paths = [NSMutableArray new];
    for (NSURL *url in en) {
        NSNumber *dir = nil, *reg = nil, *link = nil;
        [url getResourceValue:&dir forKey:NSURLIsDirectoryKey error:nil];
        [url getResourceValue:&reg forKey:NSURLIsRegularFileKey error:nil];
        [url getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:nil];
        if (link.boolValue || (!dir.boolValue && !reg.boolValue)) {
            if (error) *error = [NSError errorWithDomain:@"DmSaveSync" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Save contains an unsupported link or file type"}];
            return nil;
        }
        if (![url.path hasPrefix:[tree.path stringByAppendingString:@"/"]]) {
            if (error) *error = [NSError errorWithDomain:@"DmSaveSync" code:7 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Snapshot path mismatch: %@ vs %@", url.path, tree.path]}];
            return nil;
        }
        [paths addObject:[(dir.boolValue ? @"D:" : @"F:") stringByAppendingString:[url.path substringFromIndex:tree.path.length + 1]]];
    }
    if (scanError) { if (error) *error = scanError; return nil; }
    [paths sortUsingSelector:@selector(compare:)];
    CC_SHA256_CTX ctx; CC_SHA256_Init(&ctx);
    uint8_t buffer[65536];
    for (NSString *path in paths) {
        NSData *name = [path dataUsingEncoding:NSUTF8StringEncoding];
        uint64_t n = CFSwapInt64HostToBig(name.length);
        CC_SHA256_Update(&ctx, &n, sizeof n); CC_SHA256_Update(&ctx, name.bytes, (CC_LONG)name.length);
        NSURL *item = [tree URLByAppendingPathComponent:[path substringFromIndex:2]];
        char alias[1024]; ssize_t aliasLength = getxattr(item.fileSystemRepresentation, kGuestNameXattr, alias, sizeof alias, 0, XATTR_NOFOLLOW);
        if (aliasLength < 0 && errno != ENOATTR) { if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]; return nil; }
        uint64_t aliasBytes = CFSwapInt64HostToBig(aliasLength < 0 ? 0 : (uint64_t)aliasLength);
        CC_SHA256_Update(&ctx, &aliasBytes, sizeof aliasBytes);
        if (aliasLength > 0) CC_SHA256_Update(&ctx, alias, (CC_LONG)aliasLength);
        if ([path hasPrefix:@"D:"]) continue;
        NSInputStream *input = [NSInputStream inputStreamWithURL:item];
        [input open];
        if (input.streamStatus == NSStreamStatusError) { if (error) *error = [NSError errorWithDomain:@"DmSaveSync" code:5 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Cannot read %@: %@", path, input.streamError.localizedDescription]}]; return nil; }
        NSInteger count;
        while ((count = [input read:buffer maxLength:sizeof buffer]) > 0) CC_SHA256_Update(&ctx, buffer, (CC_LONG)count);
        NSError *readError = input.streamError; [input close];
        if (count < 0) { if (error) *error = [NSError errorWithDomain:@"DmSaveSync" code:6 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Cannot read %@: %@", path, readError.localizedDescription]}]; return nil; }
        uint8_t end = 0; CC_SHA256_Update(&ctx, &end, 1);
    }
    uint8_t digest[CC_SHA256_DIGEST_LENGTH]; CC_SHA256_Final(digest, &ctx);
    NSMutableString *hex = [NSMutableString new];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}
- (NSDictionary<NSString *, NSString *> *)aliasesInTree:(NSURL *)tree error:(NSError **)error {
    char canonical[PATH_MAX];
    if (realpath(tree.fileSystemRepresentation, canonical)) tree = [NSURL fileURLWithPath:@(canonical) isDirectory:YES];
    NSMutableDictionary *aliases = [NSMutableDictionary new];
    NSDirectoryEnumerator *en = [NSFileManager.defaultManager enumeratorAtURL:tree includingPropertiesForKeys:nil options:0 errorHandler:nil];
    for (NSURL *item in en) {
        char alias[1024]; ssize_t length = getxattr(item.fileSystemRepresentation, kGuestNameXattr, alias, sizeof alias, 0, XATTR_NOFOLLOW);
        if (length < 0) { if (errno == ENOATTR) continue; if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]; return nil; }
        NSString *name = [[NSString alloc] initWithBytes:alias length:(NSUInteger)length encoding:NSUTF8StringEncoding];
        if (!name || ![item.path hasPrefix:[tree.path stringByAppendingString:@"/"]]) { if (error) *error = [NSError errorWithDomain:@"DmSaveSync" code:8 userInfo:nil]; return nil; }
        aliases[[item.path substringFromIndex:tree.path.length + 1]] = name;
    }
    return aliases;
}
- (BOOL)restoreAliases:(NSDictionary *)aliases inTree:(NSURL *)tree error:(NSError **)error {
    if (![aliases isKindOfClass:NSDictionary.class]) return NO;
    for (NSString *path in aliases) {
        NSString *name = aliases[path];
        if (![path isKindOfClass:NSString.class] || ![name isKindOfClass:NSString.class] ||
            [path hasPrefix:@"/"] || [path containsString:@"\\"] || [path.pathComponents containsObject:@".."] || [path.pathComponents containsObject:@"."]) return NO;
        NSURL *item = [tree URLByAppendingPathComponent:path];
        NSData *value = [name dataUsingEncoding:NSUTF8StringEncoding];
        if (!value.length || value.length > 768 || setxattr(item.fileSystemRepresentation, kGuestNameXattr, value.bytes, value.length, 0, XATTR_NOFOLLOW)) {
            if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
            return NO;
        }
    }
    return YES;
}

- (NSURL *)snapshot:(NSError **)error {
    NSURL *copy = [self temporary:@"save"];
    if (clonefile(_save.fileSystemRepresentation, copy.fileSystemRepresentation, 0) == 0) return copy;
    if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Could not snapshot committed save %@ to %@ (errno %d)", _save.path, copy.path, errno]}];
    return nil;
}
- (NSDictionary *)readManifest:(NSURL *)url error:(NSError **)error {
    NSURL *manifest = [url URLByAppendingPathComponent:@"manifest.plist"];
    __block NSDictionary *entry = nil;
    NSFileCoordinator *coordinator = [NSFileCoordinator new];
    [coordinator coordinateReadingItemAtURL:manifest options:0 error:error byAccessor:^(NSURL *readURL) {
        entry = [NSDictionary dictionaryWithContentsOfURL:readURL];
    }];
    if (![entry[@"format"] isEqual:@1] || ![entry[@"titleID"] isEqual:_titleID] || ![entry[@"revision"] isKindOfClass:NSString.class] ||
        ![entry[@"hash"] isKindOfClass:NSString.class] || ![entry[@"parent"] isKindOfClass:NSString.class]) return nil;
    return entry;
}
- (NSArray<NSDictionary *> *)cloudEntries:(NSURL *)root error:(NSError **)error {
    NSArray<NSURL *> *children = [NSFileManager.defaultManager contentsOfDirectoryAtURL:root includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:error];
    if (!children) return nil;
    NSMutableArray *entries = [NSMutableArray new];
    for (NSURL *url in children) {
        if (![[NSUUID alloc] initWithUUIDString:url.lastPathComponent]) continue;
        NSDictionary *entry = [self readManifest:url error:error];
        if (!entry) { if (error && *error) return nil; continue; } // incomplete upload is ignored
        if (![entry[@"revision"] isEqual:url.lastPathComponent]) continue;
        [entries addObject:entry];
    }
    return entries;
}
- (NSDictionary *)head:(NSArray<NSDictionary *> *)entries {
    NSMutableSet *parents = [NSMutableSet new];
    for (NSDictionary *entry in entries) if ([entry[@"parent"] length]) [parents addObject:entry[@"parent"]];
    NSMutableArray *heads = [NSMutableArray new];
    for (NSDictionary *entry in entries) if (![parents containsObject:entry[@"revision"]]) [heads addObject:entry];
    return heads.count == 1 ? heads[0] : nil;
}
- (NSString *)syncNow {
    NSError *error = nil;
    NSURL *root = self.cloudRoot;
    if (!root) return _containerID.length ? @"iCloud unavailable; local saves are safe" : @"iCloud is not configured; local saves are safe";
    NSURL *snapshot = [self snapshot:&error];
    if (!snapshot) return [@"Snapshot failed: " stringByAppendingString:error.localizedDescription ?: @"unknown error"];
    NSString *hash = [self hashTree:snapshot error:&error];
    if (!hash) { [NSFileManager.defaultManager removeItemAtURL:snapshot error:nil]; return [@"Snapshot failed: " stringByAppendingString:error.localizedDescription ?: @"unknown error"]; }
    NSDictionary *aliases = [self aliasesInTree:snapshot error:&error];
    if (!aliases) { [NSFileManager.defaultManager removeItemAtURL:snapshot error:nil]; return @"Snapshot failed: save alias metadata could not be read"; }
    NSDictionary *base = self.baseline;
    NSFileManager *fm = NSFileManager.defaultManager;
    [fm createDirectoryAtURL:root withIntermediateDirectories:YES attributes:nil error:&error];
    NSArray *entries = error ? nil : [self cloudEntries:root error:&error];
    if (!entries) { [fm removeItemAtURL:snapshot error:nil]; return [@"iCloud scan failed: " stringByAppendingString:error.localizedDescription ?: @"unknown error"]; }
    NSDictionary *head = [self head:entries];
    if (entries.count && !head) { [fm removeItemAtURL:snapshot error:nil]; return @"Conflict: multiple cloud save branches; no save was overwritten"; }
    NSString *baselineRevision = base[@"revision"] ?: @"";
    BOOL localChanged = ![hash isEqual:base[@"hash"]];
    if (head && ![head[@"revision"] isEqual:baselineRevision]) {
        [fm removeItemAtURL:snapshot error:nil];
        return localChanged ? @"Conflict: local and cloud saves both changed; no save was overwritten" : @"Cloud has a newer save; choose Import Save to stage it for next launch";
    }
    if (!head && baselineRevision.length) { [fm removeItemAtURL:snapshot error:nil]; return @"Cloud save is missing; no save was overwritten"; }
    if (!localChanged) { [fm removeItemAtURL:snapshot error:nil]; return @"Save is in sync"; }
    NSString *revision = NSUUID.UUID.UUIDString;
    NSURL *package = [self temporary:@"package"];
    [fm createDirectoryAtURL:package withIntermediateDirectories:YES attributes:nil error:&error];
    if (!error) [fm moveItemAtURL:snapshot toURL:[package URLByAppendingPathComponent:@"save"] error:&error];
    NSDictionary *manifest = @{ @"format": @1, @"titleID": _titleID, @"revision": revision,
                                @"parent": baselineRevision, @"hash": hash, @"aliases": aliases, @"created": [NSDate date] };
    if (!error && ![manifest writeToURL:[package URLByAppendingPathComponent:@"manifest.plist"] atomically:YES])
        error = [NSError errorWithDomain:@"DmSaveSync" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Could not write manifest"}];
    BOOL published = NO;
    if (!error) {
        NSURL *destination = [root URLByAppendingPathComponent:revision];
        published = _testCloudRoot ? [fm moveItemAtURL:package toURL:destination error:&error]
                                   : [fm setUbiquitous:YES itemAtURL:package destinationURL:destination error:&error];
    }
    if (!error && !published)
        error = [NSError errorWithDomain:@"DmSaveSync" code:4 userInfo:@{NSLocalizedDescriptionKey:@"iCloud refused the snapshot"}];
    [fm removeItemAtURL:package error:nil];
    if (error) return [@"Cloud upload failed; local save is safe: " stringByAppendingString:error.localizedDescription];
    if (![self saveBaseline:manifest]) return @"Cloud upload queued, but local sync state could not be saved; next sync may report a conflict";
    return @"Save snapshot queued for iCloud";
}
- (void)sync:(void (^)(NSString *))completion { [self run:^{ return [self syncNow]; } completion:completion]; }

- (void)exportSave:(void (^)(NSString *))completion {
    [self run:^{ return [self exportNow]; } completion:completion];
}
- (NSString *)exportNow {
        NSError *error = nil; NSURL *snapshot = [self snapshot:&error];
        if (!snapshot) return [@"Export failed: " stringByAppendingString:error.localizedDescription ?: @"unknown error"];
        NSString *hash = [self hashTree:snapshot error:&error];
        if (!hash) { [NSFileManager.defaultManager removeItemAtURL:snapshot error:nil]; return [@"Export failed: " stringByAppendingString:error.localizedDescription ?: @"unknown error"]; }
        NSDictionary *aliases = [self aliasesInTree:snapshot error:&error];
        if (!aliases) { [NSFileManager.defaultManager removeItemAtURL:snapshot error:nil]; return @"Export failed: save alias metadata could not be read"; }
        NSURL *exports = [_documents URLByAppendingPathComponent:@"SaveExports" isDirectory:YES];
        [NSFileManager.defaultManager createDirectoryAtURL:exports withIntermediateDirectories:YES attributes:nil error:&error];
        NSURL *dest = [exports URLByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.save", _titleID, NSUUID.UUID.UUIDString] isDirectory:YES];
        if (!error) [NSFileManager.defaultManager createDirectoryAtURL:dest withIntermediateDirectories:YES attributes:nil error:&error];
        if (!error) [NSFileManager.defaultManager moveItemAtURL:snapshot toURL:[dest URLByAppendingPathComponent:@"save"] error:&error];
        if (error) { [NSFileManager.defaultManager removeItemAtURL:snapshot error:nil]; return [@"Export failed: " stringByAppendingString:error.localizedDescription]; }
        NSDictionary *manifest = @{ @"format": @1, @"titleID": _titleID, @"hash": hash, @"aliases": aliases };
        if (![manifest writeToURL:[dest URLByAppendingPathComponent:@"manifest.plist"] atomically:YES]) return @"Exported save, but its manifest could not be written";
        return [@"Exported to Files → On My iPhone → this app → SaveExports → " stringByAppendingString:dest.lastPathComponent];
}
- (void)importSaveAtURL:(NSURL *)url completion:(void (^)(NSString *))completion {
    [self run:^{ return [self importFileNow:url]; } completion:completion];
}
- (NSString *)importFileNow:(NSURL *)url {
        BOOL access = [url startAccessingSecurityScopedResource];
        @try {
            NSDictionary *manifest = [NSDictionary dictionaryWithContentsOfURL:[url URLByAppendingPathComponent:@"manifest.plist"]];
            if (![manifest[@"format"] isEqual:@1] || ![manifest[@"titleID"] isEqual:_titleID] || ![manifest[@"hash"] isKindOfClass:NSString.class])
                return @"Import refused: this export belongs to another game or has no manifest";
            __block NSError *error = nil;
            NSURL *staged = [self temporary:@"import"];
            NSFileCoordinator *coordinator = [NSFileCoordinator new];
            [coordinator coordinateReadingItemAtURL:[url URLByAppendingPathComponent:@"save"] options:0 error:&error byAccessor:^(NSURL *source) {
                [NSFileManager.defaultManager copyItemAtURL:source toURL:staged error:&error];
            }];
            if (error) return [@"Import failed: " stringByAppendingString:error.localizedDescription];
            if (![self restoreAliases:manifest[@"aliases"] ?: @{} inTree:staged error:&error]) { [NSFileManager.defaultManager removeItemAtURL:staged error:nil]; return @"Import refused: alias metadata is invalid"; }
            NSString *hash = [self hashTree:staged error:&error];
            if (!hash || ![hash isEqual:manifest[@"hash"]]) { [NSFileManager.defaultManager removeItemAtURL:staged error:nil]; return @"Import refused: export failed verification"; }
            NSURL *current = [self snapshot:&error];
            NSString *currentHash = current ? [self hashTree:current error:&error] : nil;
            [NSFileManager.defaultManager removeItemAtURL:current error:nil];
            if (!currentHash) { [NSFileManager.defaultManager removeItemAtURL:staged error:nil]; return @"Could not verify local save before import"; }
            NSDictionary *pending = @{ @"source": staged.path, @"expectedLocalHash": currentHash, @"revision": @"", @"hash": hash };
            if (![pending writeToURL:[_state URLByAppendingPathComponent:@"pending.plist"] atomically:YES]) { [NSFileManager.defaultManager removeItemAtURL:staged error:nil]; return @"Could not stage import; local save is safe"; }
            return @"Export verified and staged. Fully quit and relaunch the app to import it";
        } @finally { if (access) [url stopAccessingSecurityScopedResource]; }
}
- (void)importCloudSave:(void (^)(NSString *))completion {
    [self run:^{ return [self importCloudNow]; } completion:completion];
}
- (NSString *)importCloudNow {
        __block NSError *error = nil; NSURL *root = self.cloudRoot;
        if (!root) return @"iCloud unavailable; local saves are safe";
        NSArray *entries = [self cloudEntries:root error:&error];
        if (!entries) return [@"iCloud scan failed: " stringByAppendingString:error.localizedDescription ?: @"unknown error"];
        NSDictionary *head = [self head:entries];
        if (!head) return entries.count ? @"Conflict: multiple cloud save branches; choose a copy in Files manually" : @"No cloud save is available";
        NSURL *package = [root URLByAppendingPathComponent:head[@"revision"] isDirectory:YES];
        NSURL *source = [package URLByAppendingPathComponent:@"save" isDirectory:YES];
        NSFileCoordinator *coordinator = [NSFileCoordinator new];
        NSURL *staged = [self temporary:@"import"];
        [coordinator coordinateReadingItemAtURL:source options:0 error:&error byAccessor:^(NSURL *readURL) {
            [NSFileManager.defaultManager copyItemAtURL:readURL toURL:staged error:&error];
        }];
        if (error) { [NSFileManager.defaultManager removeItemAtURL:staged error:nil]; return [@"Cloud download pending or failed: " stringByAppendingString:error.localizedDescription]; }
        if (![self restoreAliases:head[@"aliases"] ?: @{} inTree:staged error:&error]) { [NSFileManager.defaultManager removeItemAtURL:staged error:nil]; return @"Cloud save alias metadata is invalid"; }
        NSString *hash = [self hashTree:staged error:&error];
        if (!hash || ![hash isEqual:head[@"hash"]]) { [NSFileManager.defaultManager removeItemAtURL:staged error:nil]; return @"Cloud save is incomplete or failed verification; local save is safe"; }
        NSURL *current = [self snapshot:&error];
        NSString *currentHash = current ? [self hashTree:current error:&error] : nil;
        [NSFileManager.defaultManager removeItemAtURL:current error:nil];
        if (!currentHash) { [NSFileManager.defaultManager removeItemAtURL:staged error:nil]; return @"Could not verify local save before import"; }
        NSDictionary *pending = @{ @"source": staged.path, @"expectedLocalHash": currentHash, @"revision": head[@"revision"], @"hash": hash };
        if (![pending writeToURL:[_state URLByAppendingPathComponent:@"pending.plist"] atomically:YES]) { [NSFileManager.defaultManager removeItemAtURL:staged error:nil]; return @"Could not stage import; local save is safe"; }
        return @"Cloud save verified and staged. Fully quit and relaunch the app to import it";
}

- (NSString *)applyPendingImport {
    NSURL *pendingURL = [_state URLByAppendingPathComponent:@"pending.plist"];
    NSDictionary *pending = [NSDictionary dictionaryWithContentsOfURL:pendingURL];
    if (!pending) return @"No pending save import";
    NSError *error = nil;
    NSURL *source = [NSURL fileURLWithPath:pending[@"source"] ?: @""];
    if (![source.path hasPrefix:[_state.path stringByAppendingString:@"/"]]) return @"Pending import held: invalid staging path";
    NSString *sourceHash = [self hashTree:source error:&error];
    NSString *local = [self hashTree:_save error:&error];
    BOOL alreadySwapped = [local isEqual:pending[@"hash"]] && [sourceHash isEqual:pending[@"expectedLocalHash"]];
    if (!alreadySwapped && (!sourceHash || !local || ![sourceHash isEqual:pending[@"hash"]] || ![local isEqual:pending[@"expectedLocalHash"]]))
        return @"Pending import held: staged or local save changed; no save was overwritten";
    // Only at boot, before hle_fs mounts save.work. Swap leaves the old committed
    // save available until the import and baseline are both installed.
    if (!alreadySwapped && renamex_np(source.fileSystemRepresentation, _save.fileSystemRepresentation, RENAME_SWAP) != 0)
        return [NSString stringWithFormat:@"Pending import failed (errno %d); local save is safe", errno];
    NSDictionary *base = @{ @"revision": pending[@"revision"], @"hash": pending[@"hash"] };
    BOOL stored = [pending[@"revision"] length] ? [self saveBaseline:base] : [NSFileManager.defaultManager removeItemAtURL:self.metaURL error:nil] || ![NSFileManager.defaultManager fileExistsAtPath:self.metaURL.path];
    if (!stored) {
        if (renamex_np(source.fileSystemRepresentation, _save.fileSystemRepresentation, RENAME_SWAP) == 0)
            return @"Pending import rolled back: sync state could not be saved";
        return @"Pending import needs recovery: sync state could not be saved; both save versions remain on disk";
    }
    NSURL *backups = [_state URLByAppendingPathComponent:@"ImportedBackups" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:backups withIntermediateDirectories:YES attributes:nil error:nil];
    NSURL *backup = [backups URLByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.save", _titleID, NSUUID.UUID.UUIDString]];
    [NSFileManager.defaultManager moveItemAtURL:source toURL:backup error:nil];
    [NSFileManager.defaultManager removeItemAtURL:pendingURL error:nil];
    return @"Cloud save imported before guest boot";
}
@end
