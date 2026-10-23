#import "DmGameSave.h"
@implementation DmGameSave
- (instancetype)initWithLocalSave:(NSURL *)localSave containerID:(NSString *)containerID {
    if (!(self = [super init])) return nil;
    (void)localSave; (void)containerID;
    return self;
}
// Keep host lifecycle calls stable while ensuring the deprecated GameSave/iCloud
// synchronizer cannot observe or copy save data.
- (void)startBeforeGameplay {}
- (void)resumeSafely {}
- (void)saveCommitted {}
@end
