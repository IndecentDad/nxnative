#import <Foundation/Foundation.h>
#import "DmSaveSync.h"
#include <stdio.h>
#include <sys/xattr.h>

@interface DmSaveSync (Test)
- (NSString *)syncNow;
- (NSString *)importCloudNow;
- (NSString *)importFileNow:(NSURL *)url;
- (NSString *)exportNow;
@end

static void expect(BOOL condition, NSString *message) {
    if (!condition) { fprintf(stderr, "FAIL: %s\n", message.UTF8String); exit(1); }
}
static NSURL *child(NSURL *url, NSString *name) { return [url URLByAppendingPathComponent:name]; }
static void writeSave(NSURL *docs, NSString *value) {
    NSURL *save = child(docs, @"save");
    [NSFileManager.defaultManager createDirectoryAtURL:save withIntermediateDirectories:YES attributes:nil error:nil];
    expect([value writeToURL:child(save, @"progress") atomically:YES encoding:NSUTF8StringEncoding error:nil], @"write save");
}
static NSString *readSave(NSURL *docs) {
    return [NSString stringWithContentsOfURL:child(child(docs, @"save"), @"progress") encoding:NSUTF8StringEncoding error:nil];
}
static DmSaveSync *engine(NSURL *docs, NSURL *cloud, NSString *id16) {
    [NSFileManager.defaultManager createDirectoryAtURL:docs withIntermediateDirectories:YES attributes:nil error:nil];
    return [[DmSaveSync alloc] initWithDocuments:docs titleID:id16 testCloudRoot:cloud];
}
int main(void) { @autoreleasepool {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
    NSURL *cloud = child(root, @"cloud"), *a = child(root, @"a/Documents"), *b = child(root, @"b/Documents");
    NSString *idA = @"010093801237C000", *idB = @"010015100B514000";
    DmSaveSync *first = engine(a, cloud, idA), *second = engine(b, cloud, idB);
    writeSave(a, @"v1"); writeSave(b, @"other");
    NSURL *aliasFile = child(child(a, @"save"), @".dm-case-0");
    expect([@"alias content" writeToURL:aliasFile atomically:YES encoding:NSUTF8StringEncoding error:nil], @"write case alias");
    expect(setxattr(aliasFile.fileSystemRepresentation, "org.d2rmobile.guest-name", "SAVE", 4, 0, XATTR_NOFOLLOW) == 0, @"set guest name alias");
    NSString *firstResult = [first syncNow];
    expect([firstResult containsString:@"queued"], @"first snapshot uploaded");
    expect([[first syncNow] containsString:@"in sync"], @"unchanged save is in sync");
    NSURL *published = [[fm contentsOfDirectoryAtURL:child(cloud, idA) includingPropertiesForKeys:nil options:0 error:nil] firstObject];
    NSURL *cloudAlias = child(child(published, @"save"), @".dm-case-0");
    expect(removexattr(cloudAlias.fileSystemRepresentation, "org.d2rmobile.guest-name", XATTR_NOFOLLOW) == 0, @"simulate iCloud dropping extended attribute");
    expect([[second syncNow] containsString:@"queued"], @"second game uploaded");
    expect([[fm contentsOfDirectoryAtURL:child(cloud, idA) includingPropertiesForKeys:nil options:0 error:nil] count] == 1, @"game A isolated");
    expect([[fm contentsOfDirectoryAtURL:child(cloud, idB) includingPropertiesForKeys:nil options:0 error:nil] count] == 1, @"game B isolated");
    // An incomplete publication is ignored; the committed local save remains intact.
    [fm createDirectoryAtURL:child(child(cloud, idA), NSUUID.UUID.UUIDString) withIntermediateDirectories:YES attributes:nil error:nil];
    expect([[first syncNow] containsString:@"in sync"], @"interrupted upload ignored");
    // A second device with its own local save cannot overwrite the cloud branch.
    NSURL *other = child(root, @"other/Documents"); DmSaveSync *peer = engine(other, cloud, idA);
    writeSave(other, @"peer local");
    expect([[peer syncNow] containsString:@"Conflict"], @"unrelated local save conflicts");
    expect([readSave(other) isEqualToString:@"peer local"], @"conflict preserves local save");
    // Import is staged, then applied at boot; the old committed save is retained.
    expect([[peer importCloudNow] containsString:@"staged"], @"cloud import staged");
    expect([readSave(other) isEqualToString:@"peer local"], @"gameplay still uses local save");
    expect([[peer applyPendingImport] containsString:@"imported"], @"staged import applied");
    expect([readSave(other) isEqualToString:@"v1"], @"imported content available at boot");
    char restored[8] = {0};
    expect(getxattr(child(child(other, @"save"), @".dm-case-0").fileSystemRepresentation, "org.d2rmobile.guest-name", restored, sizeof restored, 0, XATTR_NOFOLLOW) == 4 && !memcmp(restored, "SAVE", 4), @"guest filename alias restored after cloud round trip");
    writeSave(a, @"v2");
    expect([[first syncNow] containsString:@"queued"], @"new local revision uploaded");
    writeSave(other, @"peer v2");
    expect([[peer syncNow] containsString:@"Conflict"], @"divergent revisions detected");
    expect([readSave(other) isEqualToString:@"peer v2"], @"divergence preserves local data");
    NSArray *revisions = [fm contentsOfDirectoryAtURL:child(cloud, idA) includingPropertiesForKeys:nil options:0 error:nil];
    for (NSURL *revision in revisions) {
        if ([revision.lastPathComponent isEqualToString:published.lastPathComponent] || ![fm fileExistsAtPath:child(revision, @"manifest.plist").path]) continue;
        [@"damaged in transit" writeToURL:child(child(revision, @"save"), @"progress") atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    expect([[peer importCloudNow] containsString:@"failed verification"], @"corrupt cloud snapshot rejected");
    expect([readSave(other) isEqualToString:@"peer v2"], @"corrupt cloud data never replaces local save");
    expect([[first exportNow] containsString:@"Exported"], @"manual export completed");
    NSURL *exports = child(a, @"SaveExports");
    NSURL *package = [[fm contentsOfDirectoryAtURL:exports includingPropertiesForKeys:nil options:0 error:nil] firstObject];
    expect(removexattr(child(child(package, @"save"), @".dm-case-0").fileSystemRepresentation, "org.d2rmobile.guest-name", XATTR_NOFOLLOW) == 0, @"simulate Files copy dropping extended attribute");
    expect([[peer importFileNow:package] containsString:@"staged"], @"manual file import staged");
    writeSave(other, @"changed after staging");
    expect([[peer applyPendingImport] containsString:@"held"], @"interrupted import refuses newer local save");
    expect([readSave(other) isEqualToString:@"changed after staging"], @"newer local save preserved");
    expect([[peer importFileNow:package] containsString:@"staged"], @"manual import can be restaged");
    NSURL *pendingURL = child(child(child(root, @"other"), @"Library/Application Support/NXNativeSaveSync"), @"pending.plist");
    NSDictionary *pending = [NSDictionary dictionaryWithContentsOfURL:pendingURL];
    expect(renamex_np([pending[@"source"] fileSystemRepresentation], child(other, @"save").fileSystemRepresentation, RENAME_SWAP) == 0,
           @"simulate interruption after atomic import swap");
    expect([[peer applyPendingImport] containsString:@"imported"], @"interrupted import completed at boot");
    expect([readSave(other) isEqualToString:@"v2"], @"manual import contents verified");
    expect(getxattr(child(child(other, @"save"), @".dm-case-0").fileSystemRepresentation, "org.d2rmobile.guest-name", restored, sizeof restored, 0, XATTR_NOFOLLOW) == 4, @"guest alias restored after Files import");
    // Offline operation does not touch the local save.
    DmSaveSync *offline = [[DmSaveSync alloc] initWithDocuments:other titleID:idA containerID:@""];
    expect([[offline syncNow] containsString:@"not configured"], @"offline status");
    expect([readSave(other) isEqualToString:@"v2"], @"offline local save preserved");
    [fm removeItemAtURL:root error:nil];
    puts("save sync tests passed"); return 0;
}}
