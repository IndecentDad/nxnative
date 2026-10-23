#import "DmSettingsViewController.h"
#import "DmSaveFolderSync.h"

@interface DmSettingsViewController : UITableViewController
@property(nonatomic,strong) DmSaveFolderSync *sync;
@property(nonatomic,strong) UISegmentedControl *mode;
@property(nonatomic,strong) UILabel *folder;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UISwitch *enabled;
@end

@implementation DmSettingsViewController
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 7; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return @"Save Folder Sync"; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"NXNative Settings"; self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncNotice:) name:DmSaveFolderSyncNotice object:nil];
}
- (void)done { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)syncNotice:(NSNotification *)n { dispatch_async(dispatch_get_main_queue(), ^{ self.status.text = n.object; [self.tableView reloadData]; }); }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:@"settings"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"settings"];
    c.textLabel.text = c.detailTextLabel.text = nil; c.accessoryView = nil; c.accessoryType = UITableViewCellAccessoryNone;
    if (ip.row == 0) {
        c.textLabel.text = @"Sync mode"; self.mode = [[UISegmentedControl alloc] initWithItems:@[@"NXNative Folder", @"Eden Compatible"]]; self.mode.selectedSegmentIndex = self.sync.mode; [self.mode addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged]; c.accessoryView = self.mode;
    } else if (ip.row == 1) {
        c.textLabel.text = self.sync.selectedFolder ? @"Change Folder" : @"Select Folder"; c.detailTextLabel.text = self.sync.selectedFolderName ?: @"No folder selected"; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (ip.row == 2) {
        c.textLabel.text = @"Eden folder location"; c.textLabel.font = [UIFont italicSystemFontOfSize:15]; c.detailTextLabel.text = @"Select your Eden profile folder located at Eden → user → save → 0000000000000000 → [Profile Folder]. This folder contains your games’ title-ID folders."; c.detailTextLabel.numberOfLines = 0; c.hidden = self.sync.mode != DmSaveFolderSyncModeEden;
    } else if (ip.row == 3) {
        c.textLabel.text = @"Enable synchronization"; self.enabled = [UISwitch new]; self.enabled.on = self.sync.enabled; [self.enabled addTarget:self action:@selector(enabledChanged:) forControlEvents:UIControlEventValueChanged]; c.accessoryView = self.enabled;
    } else if (ip.row == 4) {
        c.textLabel.text = @"Sync Now"; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (ip.row == 5) {
        c.textLabel.text = self.sync.state == DmSaveFolderSyncStateNeedsResolution ? @"Resolve Conflicts" : @"Status"; self.status = c.detailTextLabel; c.detailTextLabel.text = self.sync.statusText; c.detailTextLabel.numberOfLines = 0;
    } else {
        c.textLabel.text = @"Last successful sync"; c.detailTextLabel.text = self.sync.lastSuccessfulSync ? self.sync.lastSuccessfulSync.description : @"Never";
    }
    if (ip.row == 5 && self.sync.state != DmSaveFolderSyncStateNeedsResolution) c.userInteractionEnabled = NO;
    return c;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tableView deselectRowAtIndexPath:ip animated:YES];
    if (ip.row == 1) [self.sync presentFolderPickerFromViewController:self];
    else if (ip.row == 4) [self.sync syncNow];
    else if (ip.row == 5 && self.sync.state == DmSaveFolderSyncStateNeedsResolution) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Resolve Conflicts" message:@"Choose which complete save to keep. The other side will not be overwritten until you choose." preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Import external" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x) { [self.sync resolveByImportingExternal]; }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Export local" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x) { [self.sync resolveByExportingLocal]; }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Preserve both" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *x) { [self.sync preserveBoth]; }]]; [self presentViewController:a animated:YES completion:nil];
    }
}
- (void)modeChanged:(UISegmentedControl *)s { self.sync.mode = s.selectedSegmentIndex; [self.tableView reloadData]; }
- (void)enabledChanged:(UISwitch *)s { self.sync.enabled = s.isOn; if (s.isOn) [self.sync startBeforeGameplay]; }
@end

UIViewController *DmMakeSettingsViewController(DmSaveFolderSync *sync) {
    DmSettingsViewController *vc = [[DmSettingsViewController alloc] initWithStyle:UITableViewStyleInsetGrouped]; vc.sync = sync;
    return [[UINavigationController alloc] initWithRootViewController:vc];
}
