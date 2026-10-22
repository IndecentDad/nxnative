#import <Foundation/Foundation.h>

/// GameSave-backed synchronization for one game's local Documents/save tree.
/// The local tree remains authoritative while the guest is running.
@interface DmGameSave : NSObject
- (instancetype)initWithLocalSave:(NSURL *)localSave containerID:(NSString *)containerID;
- (void)startBeforeGameplay;
- (void)resumeSafely;
- (void)saveCommitted;
@end
