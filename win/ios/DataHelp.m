// The screen an app shows when it finds no game files (front_ios.m, main.m boot_env found no romfs): a split build (win/build_app.py, NXW_SPLIT_DATA) ships the game files
// as a separate "<Game>-data" folder, which the player copies into the app's Documents once. The screen says where it goes, step by step, names the folder the build made
// (NXWDataFolder in Info.plist), shows the size it takes and the space free, and "Check again" looks for it without restarting (the game itself starts on the next launch,
// since the host's environment is set before UIKit starts). Drawn in the launcher's style: the game card on the left, the steps in an inset-grouped list on the right.
#import <UIKit/UIKit.h>

int nxw_data_found(void);   // main.m: a romfs with the game's marker in Documents, in a folder directly inside it, or in the app

static id info(NSString *k) { return [NSBundle.mainBundle objectForInfoDictionaryKey:k]; }

@interface NxwDataHelpVC : UITableViewController
@property (copy) NSArray<NSArray<NSString *> *> *steps;   // [title, detail]
@property (copy) NSString *status;
@end
@implementation NxwDataHelpVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.rowHeight = UITableViewAutomaticDimension; self.tableView.estimatedRowHeight = 64;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 3; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == 0 ? (NSInteger)self.steps.count : 1; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return s == 0 ? @"Copy the game data" : nil; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    if (s == 0) return @"The folder can keep its name: the app looks in Documents and in every folder directly inside it. Re-signing or reinstalling the app keeps Documents.";
    if (s == 1) return self.status;
    return nil;
}
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    c.selectionStyle = UITableViewCellSelectionStyleNone;
    if (ip.section == 0) {
        UIListContentConfiguration *cfg = [UIListContentConfiguration subtitleCellConfiguration];
        cfg.text = self.steps[ip.row][0]; cfg.secondaryText = self.steps[ip.row][1];
        cfg.secondaryTextProperties.color = UIColor.secondaryLabelColor; cfg.textToSecondaryTextVerticalPadding = 4;
        cfg.image = [UIImage systemImageNamed:[NSString stringWithFormat:@"%ld.circle.fill", (long)ip.row + 1]];
        cfg.imageProperties.tintColor = UIColor.systemPinkColor;
        c.contentConfiguration = cfg;
    } else if (ip.section == 1) {
        UIListContentConfiguration *cfg = [UIListContentConfiguration cellConfiguration];
        cfg.text = @"Check again"; cfg.textProperties.color = UIColor.systemPinkColor; cfg.textProperties.alignment = UIListContentTextAlignmentCenter;
        c.contentConfiguration = cfg; c.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else {
        UIListContentConfiguration *cfg = [UIListContentConfiguration valueCellConfiguration];
        NSDictionary *a = [NSFileManager.defaultManager attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
        cfg.text = @"Free space on this device";
        cfg.secondaryText = [NSByteCountFormatter stringFromByteCount:[a[NSFileSystemFreeSize] longLongValue] countStyle:NSByteCountFormatterCountStyleFile];
        c.contentConfiguration = cfg;
    }
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != 1) return;
    self.status = nxw_data_found() ? @"Found. Close the app fully (swipe it away in the app switcher) and open it again to play."
                                   : @"Not found yet. A large folder can take several minutes to copy; check that romfs is inside it.";
    [tv reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
}
@end

// Shows the screen in the root view controller's view (front_ios.m calls it instead of the plain hint)
void nxw_show_data_help(UIViewController *root) {
    NSString *folder = [info(@"NXWDataFolder") isKindOfClass:NSString.class] ? info(@"NXWDataFolder") : @"the game's data folder";
    NSString *size = [info(@"NXWDataSize") isKindOfClass:NSString.class] ? info(@"NXWDataSize") : nil;
    NSString *name = [info(@"CFBundleDisplayName") isKindOfClass:NSString.class] ? info(@"CFBundleDisplayName") : @"this app";
    NxwDataHelpVC *list = [[NxwDataHelpVC alloc] initWithStyle:UITableViewStyleInsetGrouped];
    list.steps = @[
        @[@"Find the data folder", [NSString stringWithFormat:@"On your PC, next to the IPA: \"%@\"%@ (romfs, msl and aoc inside).", folder, size ? [NSString stringWithFormat:@", %@", size] : @""]],
        @[@"From Windows", [NSString stringWithFormat:@"Apple Devices app (or iTunes) → this device → Files → %@ → drag the whole folder in.", name]],
        @[@"Or on this device", [NSString stringWithFormat:@"Files app → On My %@ → %@ → paste the folder (from a USB drive, a network share or iCloud Drive).", UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? @"iPad" : @"iPhone", name]],
        @[@"Restart the app", @"Close the app fully and open it again. The launcher appears, then press Play."],
    ];
    root.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    root.view.backgroundColor = UIColor.systemGroupedBackgroundColor;

    UIStackView *card = [UIStackView new]; card.axis = UILayoutConstraintAxisVertical; card.alignment = UIStackViewAlignmentCenter; card.spacing = 12;
    UIImage *icon = [UIImage imageNamed:@"AppIcon60x60"];
    if (icon) {
        UIImageView *iv = [[UIImageView alloc] initWithImage:icon]; iv.layer.cornerRadius = 22; iv.layer.cornerCurve = kCACornerCurveContinuous; iv.clipsToBounds = YES;
        [iv.widthAnchor constraintEqualToConstant:96].active = YES; [iv.heightAnchor constraintEqualToConstant:96].active = YES; [card addArrangedSubview:iv];
    }
    UILabel *t = [UILabel new]; t.text = name; t.numberOfLines = 0; t.textAlignment = NSTextAlignmentCenter;
    t.font = [UIFont fontWithDescriptor:[[UIFont preferredFontForTextStyle:UIFontTextStyleTitle1].fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold] size:0];
    [card addArrangedSubview:t];
    UILabel *s = [UILabel new]; s.text = @"Game data needed"; s.textColor = UIColor.systemPinkColor; s.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]; [card addArrangedSubview:s];
    UILabel *d = [UILabel new]; d.numberOfLines = 0; d.textAlignment = NSTextAlignmentCenter; d.textColor = UIColor.secondaryLabelColor;
    d.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCallout];
    d.text = @"This app was built small: the game files come in a separate folder, copied into the app once.";
    [card addArrangedSubview:d];
    card.translatesAutoresizingMaskIntoConstraints = NO; [root.view addSubview:card];

    [root addChildViewController:list]; list.view.translatesAutoresizingMaskIntoConstraints = NO; [root.view addSubview:list.view]; [list didMoveToParentViewController:root];
    UIView *v = root.view; UILayoutGuide *safe = v.safeAreaLayoutGuide, *left = [UILayoutGuide new]; [v addLayoutGuide:left];
    [NSLayoutConstraint activateConstraints:@[
        [list.view.topAnchor constraintEqualToAnchor:v.topAnchor], [list.view.bottomAnchor constraintEqualToAnchor:v.bottomAnchor],
        [list.view.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor], [list.view.widthAnchor constraintEqualToAnchor:safe.widthAnchor multiplier:0.6],
        [left.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor], [left.trailingAnchor constraintEqualToAnchor:list.view.leadingAnchor],
        [card.centerXAnchor constraintEqualToAnchor:left.centerXAnchor], [card.centerYAnchor constraintEqualToAnchor:v.centerYAnchor],
        [card.widthAnchor constraintLessThanOrEqualToAnchor:left.widthAnchor constant:-32]]];
    fprintf(stderr, "boot: no game files: showing where the data folder (%s) goes\n", folder.UTF8String);
}
