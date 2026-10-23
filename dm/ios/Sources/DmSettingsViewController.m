#import "DmSettingsViewController.h"
#import "DmSaveFolderSync.h"

@interface DmSettingsViewController : UITableViewController
@property(nonatomic,strong) DmSaveFolderSync *sync;
@end

@implementation DmSettingsViewController
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 2; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return @"Save Folder Sync"; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"NXNative Settings"; self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncNotice:) name:DmSaveFolderSyncNotice object:nil];
}
- (void)done { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)syncNotice:(NSNotification *)n { (void)n; dispatch_async(dispatch_get_main_queue(), ^{ [self.tableView reloadData]; }); }
- (NSString *)statusSummary {
    if (!self.sync.selectedFolder) return @"Not Configured";
    if (self.sync.state == DmSaveFolderSyncStateNeedsResolution) return @"Conflict";
    if (self.sync.state == DmSaveFolderSyncStateUnavailable || self.sync.state == DmSaveFolderSyncStateError) return @"Error";
    if ([self.sync.statusText isEqualToString:@"Syncing"]) return @"Syncing";
    return @"Up to Date";
}
- (NSString *)syncDetail {
    NSString *last = self.sync.lastSuccessfulSync ? self.sync.lastSuccessfulSync.description : @"Never";
    NSString *message = self.sync.statusText.length ? self.sync.statusText : [self statusSummary];
    return [NSString stringWithFormat:@"%@\nLast sync: %@", message, last];
}
- (void)clearFolder {
    [self.sync clearSelectedFolder];
    [self.tableView reloadData];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:@"settings"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"settings"];
    c.textLabel.text = c.detailTextLabel.text = nil; c.accessoryView = nil; c.accessoryType = UITableViewCellAccessoryNone;
    if (ip.row == 0) {
        c.textLabel.text = self.sync.selectedFolderName ?: @"Sync Folder";
        c.detailTextLabel.text = [NSString stringWithFormat:@"Save Format: Selected Folder / %@ / Save Files", self.sync.titleID];
        c.detailTextLabel.numberOfLines = 1; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (self.sync.selectedFolder) {
            UIButton *clear = [UIButton buttonWithType:UIButtonTypeSystem]; clear.frame = CGRectMake(0, 0, 32, 32); [clear setTitle:@"×" forState:UIControlStateNormal]; clear.titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightRegular]; clear.accessibilityLabel = @"Clear selected folder"; [clear addTarget:self action:@selector(clearFolder) forControlEvents:UIControlEventTouchUpInside]; c.accessoryView = clear;
        }
    } else {
        c.textLabel.text = @"Sync Now"; c.detailTextLabel.text = [self syncDetail]; c.detailTextLabel.numberOfLines = 0; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        c.userInteractionEnabled = self.sync.selectedFolder != nil && self.sync.state != DmSaveFolderSyncStateUnavailable;
    }
    return c;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tableView deselectRowAtIndexPath:ip animated:YES];
    if (ip.row == 0) [self.sync presentFolderPickerFromViewController:self];
    else if (self.sync.state == DmSaveFolderSyncStateNeedsResolution) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Resolve Conflicts" message:@"Choose which complete save to keep. The other side will not be overwritten until you choose." preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Use Folder Saves" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x) { [self.sync resolveByImportingExternal]; }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Use Device Saves" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x) { [self.sync resolveByExportingLocal]; }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Preserve both" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *x) { [self.sync preserveBoth]; }]]; [self presentViewController:a animated:YES completion:nil];
    } else [self.sync syncNow];
}
@end

UIViewController *DmMakeSettingsViewController(DmSaveFolderSync *sync) {
    DmSettingsViewController *vc = [[DmSettingsViewController alloc] initWithStyle:UITableViewStyleInsetGrouped]; vc.sync = sync;
    return [[UINavigationController alloc] initWithRootViewController:vc];
}
