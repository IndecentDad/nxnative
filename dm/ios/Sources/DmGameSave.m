#import "DmGameSave.h"
#import <GameSave/GameSave.h>

NSString * const DmGameSaveNotice = @"DmGameSaveNotice";

@interface DmGameSave ()
@property(nonatomic,strong) NSURL *localSave;
@property(nonatomic,copy) NSString *containerID;
@property(nonatomic,strong) GSSyncedDirectory *directory;
@property(nonatomic,assign) BOOL started;
@end

@implementation DmGameSave
- (instancetype)initWithLocalSave:(NSURL *)localSave containerID:(NSString *)containerID {
    if (!(self = [super init])) return nil;
    _localSave = localSave; _containerID = [containerID copy]; return self;
}
- (void)notice:(NSString *)message {
    NSLog(@"GameSave: %@", message);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DmGameSaveNotice object:message];
    });
}
- (BOOL)hasSaveData:(NSURL *)url {
    NSArray *items = [NSFileManager.defaultManager contentsOfDirectoryAtURL:url includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    return items.count != 0;
}
- (BOOL)copyContents:(NSURL *)source to:(NSURL *)destination error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSURL *item in [fm contentsOfDirectoryAtURL:source includingPropertiesForKeys:nil options:0 error:error]) {
        if (*error) return NO;
        NSURL *target = [destination URLByAppendingPathComponent:item.lastPathComponent];
        if (![fm copyItemAtURL:item toURL:target error:error]) return NO;
    }
    return YES;
}
- (BOOL)stageContents:(NSURL *)source replacingEmpty:(NSURL *)destination error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *staged = [destination URLByAppendingPathExtension:[NSString stringWithFormat:@"restore-%@", NSUUID.UUID.UUIDString]];
    [fm removeItemAtURL:staged error:nil];
    if (![fm createDirectoryAtURL:staged withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    if (![self copyContents:source to:staged error:error]) { [fm removeItemAtURL:staged error:nil]; return NO; }
    NSURL *backup = [destination URLByAppendingPathExtension:[NSString stringWithFormat:@"empty-%@", NSUUID.UUID.UUIDString]];
    if (![fm moveItemAtURL:destination toURL:backup error:error]) { [fm removeItemAtURL:staged error:nil]; return NO; }
    if (![fm moveItemAtURL:staged toURL:destination error:error]) {
        [fm moveItemAtURL:backup toURL:destination error:nil];
        [fm removeItemAtURL:staged error:nil];
        return NO;
    }
    [fm removeItemAtURL:backup error:nil];
    return YES;
}
- (void)finishSyncing {
    GSSyncedDirectoryState *state = self.directory.directoryState;
    if (state.state == GSSyncStateError || state.state == GSSyncStateOffline || state.state == GSSyncStateLocal) {
        [self notice:@"iCloud save freshness could not be confirmed; local save preserved"]; return;
    }
    if (state.state == GSSyncStateConflicted) {
        [self notice:@"iCloud save conflict detected; local save preserved"]; return;
    }
    NSURL *cloud = state.url;
    if (!cloud) { [self notice:@"iCloud save freshness could not be confirmed; local save preserved"]; return; }
    NSFileManager *fm = NSFileManager.defaultManager; NSError *error = nil;
    BOOL hasLocal = [self hasSaveData:self.localSave];
    BOOL hasCloud = [self hasSaveData:cloud];
    if (hasCloud && !hasLocal) {
        [self stageContents:cloud replacingEmpty:self.localSave error:&error];
        if (!error) [self notice:@"Newer iCloud save restored"];
    } else if (hasLocal && !hasCloud) {
        [self copyContents:self.localSave to:cloud error:&error];
        if (error) [self notice:@"iCloud upload unavailable; local save preserved"];
    } else if (hasLocal && hasCloud) {
        [self notice:@"iCloud save differs from local progress; local save preserved"];
    }
    [self.directory triggerPendingUploadWithCompletionHandler:^(BOOL uploaded) {
        if (!uploaded) NSLog(@"GameSave: upload remains pending");
    }];
}
- (void)startBeforeGameplay {
    if (self.started || !self.containerID.length) return;
    self.started = YES;
    self.directory = [GSSyncedDirectory openDirectoryForContainerIdentifier:self.containerID];
    [self.directory finishSyncingWithCompletionHandler:^{ [self finishSyncing]; }];
}
- (void)resumeSafely {
    if (!self.containerID.length) return;
    [self.directory close]; self.started = NO; [self startBeforeGameplay];
}
- (void)saveCommitted {
    if (!self.containerID.length) return;
    [self.directory close];
    self.started = NO;
    self.directory = [GSSyncedDirectory openDirectoryForContainerIdentifier:self.containerID];
    self.started = YES;
    [self.directory triggerPendingUploadWithCompletionHandler:^(BOOL uploaded) {
        if (!uploaded) NSLog(@"GameSave: completed save has no pending upload");
    }];
}
@end
