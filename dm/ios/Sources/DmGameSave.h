#import <Foundation/Foundation.h>

/// Compatibility lifecycle hook for the retired GameSave iCloud synchronizer.
/// Save Folder Sync owns all user-selected external-folder synchronization.
@interface DmGameSave : NSObject
- (instancetype)initWithLocalSave:(NSURL *)localSave containerID:(NSString *)containerID;
- (void)startBeforeGameplay;
- (void)resumeSafely;
- (void)saveCommitted;
@end
