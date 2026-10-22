#import <Foundation/Foundation.h>

// Saves are always played from Documents/save.work. This service only reads the
// committed Documents/save tree and never changes it while the guest is running.
@interface DmSaveSync : NSObject
- (instancetype)initWithDocuments:(NSURL *)documents titleID:(NSString *)titleID containerID:(NSString *)containerID;
// A local cloud root makes the same engine testable without an Apple account.
- (instancetype)initWithDocuments:(NSURL *)documents titleID:(NSString *)titleID testCloudRoot:(NSURL *)cloudRoot;
- (void)sync:(void (^)(NSString *status))completion;
- (void)exportSave:(void (^)(NSString *status))completion;
- (void)importCloudSave:(void (^)(NSString *status))completion;
- (void)importSaveAtURL:(NSURL *)url completion:(void (^)(NSString *status))completion;
- (NSString *)status;
// Called before the host mounts save.work on the next launch.
- (NSString *)applyPendingImport;
@end
