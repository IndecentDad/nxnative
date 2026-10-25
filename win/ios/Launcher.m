// Launcher for the Windows build: a UIKit port of dm/ios/Sources/Launcher.swift (SwiftUI), so the app builds with clang alone (no Swift toolchain).
// Same contract as the Swift one: dm_show_launcher(view controller, done) shows the settings screen over the root view controller, puts every setting into the environment when Play
// is pressed and then calls done; it returns false (done is not called) when there is no launcher (no dm/launcher.json, DM_LAUNCHER=0, or a file it cannot read).
// Settings come from the app's dm/launcher.json (dm/games/settings.py): kind "choice" (options [[value, label]]), "range" (min / max / step, shown as a percentage) or a toggle ("1" / "0").
// A variable an env file set (DM_ENV_FILE_KEYS, main.m) is shown but kept. Choices are kept in NSUserDefaults under "launcher.<ENV>", as the Swift launcher does.
#import <UIKit/UIKit.h>
#include <os/proc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

@interface DmSetting : NSObject
@property (copy) NSString *env, *kind, *label, *note, *def;
@property (copy) NSArray<NSArray<NSString *> *> *options;   // choice: [value, label]
@property double min, max, step; @property BOOL hasMin, hasMax, hasStep;
@end
@implementation DmSetting
@end

static NSString *str(NSDictionary *d, NSString *k) { id v = d[k]; return [v isKindOfClass:NSString.class] ? v : nil; }

static NSArray<DmSetting *> *load_settings(NSData *data) {   // nil when the file does not decode (every row needs env, kind, label, note and default, as Launcher.swift's Decodable)
    id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![root isKindOfClass:NSDictionary.class] || ![root[@"settings"] isKindOfClass:NSArray.class]) return nil;
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *d in root[@"settings"]) {
        if (![d isKindOfClass:NSDictionary.class]) return nil;
        DmSetting *s = [DmSetting new];
        s.env = str(d, @"env"); s.kind = str(d, @"kind"); s.label = str(d, @"label"); s.note = str(d, @"note"); s.def = str(d, @"default");
        if (!s.env || !s.kind || !s.label || !s.note || !s.def) return nil;
        if ([d[@"options"] isKindOfClass:NSArray.class]) {
            NSMutableArray *opts = [NSMutableArray array];
            for (id o in d[@"options"]) {
                if (![o isKindOfClass:NSArray.class] || [o count] < 2 || ![o[0] isKindOfClass:NSString.class] || ![o[1] isKindOfClass:NSString.class]) return nil;
                [opts addObject:@[o[0], o[1]]];
            }
            s.options = opts;
        }
        if ([d[@"min"] isKindOfClass:NSNumber.class]) { s.min = [d[@"min"] doubleValue]; s.hasMin = YES; }
        if ([d[@"max"] isKindOfClass:NSNumber.class]) { s.max = [d[@"max"] doubleValue]; s.hasMax = YES; }
        if ([d[@"step"] isKindOfClass:NSNumber.class]) { s.step = [d[@"step"] doubleValue]; s.hasStep = YES; }
        [out addObject:s];
    }
    return out;
}

// ---- model ----
@interface DmLauncherModel : NSObject
@property (strong) NSArray<DmSetting *> *settings;
@property (strong) NSSet<NSString *> *fromFile;   // set by an env file: shown, not changed
@property (strong) NSMutableDictionary<NSString *, NSString *> *values;
@end
@implementation DmLauncherModel
- (instancetype)initWith:(NSArray<DmSetting *> *)settings {
    if (!(self = [super init])) return nil;
    _settings = settings; _values = [NSMutableDictionary dictionary];
    NSString *keys = NSProcessInfo.processInfo.environment[@"DM_ENV_FILE_KEYS"] ?: @"";
    NSMutableSet *ff = [NSMutableSet set];
    for (NSString *k in [keys componentsSeparatedByString:@" "]) if (k.length) [ff addObject:k];
    _fromFile = ff;
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    for (DmSetting *s in settings) {
        NSString *envv = NSProcessInfo.processInfo.environment[s.env];
        if ([ff containsObject:s.env] && envv) { _values[s.env] = envv; continue; }
        NSString *saved = [ud stringForKey:[@"launcher." stringByAppendingString:s.env]];
        BOOL offered = saved && (!s.options || [s.options indexOfObjectPassingTest:^BOOL(NSArray *o, NSUInteger i, BOOL *stop) { return [o[0] isEqualToString:saved]; }] != NSNotFound);
        _values[s.env] = offered ? saved : s.def;   // a saved choice the game no longer offers: its default
    }
    return self;
}
- (NSString *)value:(DmSetting *)s { return self.values[s.env] ?: s.def; }
- (BOOL)locked:(DmSetting *)s { return [self.fromFile containsObject:s.env]; }
- (NSString *)note:(DmSetting *)s {
    if (![self locked:s]) return s.note;
    return [NSString stringWithFormat:@"%@Set by an env file", s.note.length ? [s.note stringByAppendingString:@" · "] : @""];
}
- (double)rangeValue:(DmSetting *)s {
    NSString *v = [self value:s]; NSScanner *sc = [NSScanner scannerWithString:v]; double d;
    return ([sc scanDouble:&d] && sc.isAtEnd) ? d : (s.hasMax ? s.max : 1);
}
- (NSString *)percentage:(DmSetting *)s { return [NSString stringWithFormat:@"%ld %%", lround([self rangeValue:s] * 100)]; }
- (void)apply {   // before the game starts: every setting not set by an env file goes into the environment (DM_LANG replaces the packed language main.m set as a default)
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    for (DmSetting *s in self.settings) {
        NSString *v = [self value:s];
        if ([self locked:s]) { fprintf(stderr, "launcher: %s kept at %s (env file)\n", s.env.UTF8String, v.UTF8String); continue; }
        [ud setObject:v forKey:[@"launcher." stringByAppendingString:s.env]];
        setenv(s.env.UTF8String, v.UTF8String, 1); fprintf(stderr, "launcher: %s=%s\n", s.env.UTF8String, v.UTF8String);
    }
}
@end

static UIView *label_stack(NSString *title, NSString *note) {
    UILabel *a = [UILabel new]; a.text = title; a.numberOfLines = 0; a.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    UIStackView *st = [[UIStackView alloc] initWithArrangedSubviews:@[a]]; st.axis = UILayoutConstraintAxisVertical; st.spacing = 4;
    if (note.length) {
        UILabel *b = [UILabel new]; b.text = note; b.numberOfLines = 0; b.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]; b.textColor = UIColor.secondaryLabelColor;
        [st addArrangedSubview:b];
    }
    st.translatesAutoresizingMaskIntoConstraints = NO;
    return st;
}

static UITableViewCell *cell_with(UIView *left, UIView *right) {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    [c.contentView addSubview:left];
    UILayoutGuide *m = c.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[[left.leadingAnchor constraintEqualToAnchor:m.leadingAnchor], [left.topAnchor constraintEqualToAnchor:m.topAnchor],
                                              [left.bottomAnchor constraintEqualToAnchor:m.bottomAnchor]]];
    if (right) {
        right.translatesAutoresizingMaskIntoConstraints = NO; [c.contentView addSubview:right];
        [right setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [NSLayoutConstraint activateConstraints:@[[right.trailingAnchor constraintEqualToAnchor:m.trailingAnchor], [right.centerYAnchor constraintEqualToAnchor:c.contentView.centerYAnchor],
                                                  [left.trailingAnchor constraintLessThanOrEqualToAnchor:right.leadingAnchor constant:-8]]];
    } else [left.trailingAnchor constraintEqualToAnchor:m.trailingAnchor].active = YES;
    return c;
}

static UILabel *detail_label(NSString *text) {
    UILabel *l = [UILabel new]; l.text = text; l.textColor = UIColor.secondaryLabelColor;
    l.font = [UIFont monospacedDigitSystemFontOfSize:[UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize weight:UIFontWeightRegular];
    return l;
}

// ---- a choice's options ----
@interface DmChoiceVC : UITableViewController
@property (strong) DmLauncherModel *m; @property (strong) DmSetting *s; @property (copy) void (^changed)(void);
@end
@implementation DmChoiceVC
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec { return self.s.options.count; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    NSArray *o = self.s.options[ip.row]; c.textLabel.text = o[1];
    c.accessoryType = [o[0] isEqualToString:[self.m value:self.s]] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return c;
}
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)sec { NSString *n = [self.m note:self.s]; return n.length ? n : nil; }
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    self.m.values[self.s.env] = self.s.options[ip.row][0];
    [tv reloadData]; if (self.changed) self.changed();
    [self.navigationController popViewControllerAnimated:YES];
}
@end

// ---- a range's slider ----
@interface DmRangeVC : UITableViewController
@property (strong) DmLauncherModel *m; @property (strong) DmSetting *s; @property (copy) void (^changed)(void);
@property (strong) UILabel *pct;
@end
@implementation DmRangeVC
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec { return 2; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.row == 0) { self.pct = detail_label([self.m percentage:self.s]); UITableViewCell *c = cell_with(label_stack(self.s.label, nil), self.pct); c.selectionStyle = UITableViewCellSelectionStyleNone; return c; }
    UISlider *sl = [UISlider new];
    sl.minimumValue = self.s.hasMin ? self.s.min : 0; sl.maximumValue = self.s.hasMax ? self.s.max : 1; sl.value = [self.m rangeValue:self.s];
    sl.enabled = ![self.m locked:self.s]; sl.accessibilityLabel = self.s.label;
    [sl addTarget:self action:@selector(slid:) forControlEvents:UIControlEventValueChanged];
    sl.translatesAutoresizingMaskIntoConstraints = NO;
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil]; c.selectionStyle = UITableViewCellSelectionStyleNone;
    [c.contentView addSubview:sl]; UILayoutGuide *g = c.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[[sl.leadingAnchor constraintEqualToAnchor:g.leadingAnchor], [sl.trailingAnchor constraintEqualToAnchor:g.trailingAnchor],
                                              [sl.topAnchor constraintEqualToAnchor:g.topAnchor], [sl.bottomAnchor constraintEqualToAnchor:g.bottomAnchor]]];
    return c;
}
- (void)slid:(UISlider *)sl {
    double step = self.s.hasStep ? self.s.step : 0.05, lo = self.s.hasMin ? self.s.min : 0;
    double v = step > 0 ? lo + round((sl.value - lo) / step) * step : sl.value;   // SwiftUI's Slider(step:) snaps the same way
    sl.value = v;
    self.m.values[self.s.env] = [NSString stringWithFormat:@"%.2f", v];
    self.pct.text = [self.m percentage:self.s]; sl.accessibilityValue = self.pct.text;
    if (self.changed) self.changed();
}
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)sec { NSString *n = [self.m note:self.s]; return n.length ? n : nil; }
@end

// ---- the settings list ----
@interface DmSettingsVC : UITableViewController
@property (strong) DmLauncherModel *m; @property (strong) NSTimer *timer; @property (strong) UILabel *memory;
@end
@implementation DmSettingsVC
- (void)viewDidLoad {
    [super viewDidLoad];
    __weak DmSettingsVC *w = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *t) { w.memory.text = [NSByteCountFormatter stringFromByteCount:(long long)os_proc_available_memory() countStyle:NSByteCountFormatterCountStyleMemory]; }];
}
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; [self.navigationController setNavigationBarHidden:YES animated:a]; [self.tableView reloadData]; }
- (void)dealloc { [self.timer invalidate]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec { return sec == 0 ? self.m.settings.count : 1; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.section == 1) {
        self.memory = detail_label([NSByteCountFormatter stringFromByteCount:(long long)os_proc_available_memory() countStyle:NSByteCountFormatterCountStyleMemory]);
        UITableViewCell *c = cell_with(label_stack(@"Memory available", nil), self.memory); c.selectionStyle = UITableViewCellSelectionStyleNone; return c;
    }
    DmSetting *s = self.m.settings[ip.row]; BOOL locked = [self.m locked:s]; UITableViewCell *c;
    if ([s.kind isEqualToString:@"choice"]) {
        NSString *cur = [self.m value:s];
        for (NSArray *o in s.options) if ([o[0] isEqualToString:cur]) cur = o[1];
        c = cell_with(label_stack(s.label, [self.m note:s]), detail_label(cur)); c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if ([s.kind isEqualToString:@"range"]) {
        c = cell_with(label_stack(s.label, [self.m note:s]), detail_label([self.m percentage:s])); c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        UISwitch *sw = [UISwitch new]; sw.on = [[self.m value:s] isEqualToString:@"1"]; sw.enabled = !locked; sw.tag = ip.row;
        [sw addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
        c = cell_with(label_stack(s.label, [self.m note:s]), sw); c.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    if (locked) { c.userInteractionEnabled = NO; c.contentView.alpha = 0.5; }
    return c;
}
- (void)toggled:(UISwitch *)sw { DmSetting *s = self.m.settings[sw.tag]; self.m.values[s.env] = sw.on ? @"1" : @"0"; }
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != 0) return;
    DmSetting *s = self.m.settings[ip.row];
    __weak UITableView *wt = tv; void (^changed)(void) = ^{ [wt reloadData]; };
    UITableViewController *vc;
    if ([s.kind isEqualToString:@"choice"]) { DmChoiceVC *c = [[DmChoiceVC alloc] initWithStyle:UITableViewStyleInsetGrouped]; c.m = self.m; c.s = s; c.changed = changed; vc = c; }
    else if ([s.kind isEqualToString:@"range"]) { DmRangeVC *r = [[DmRangeVC alloc] initWithStyle:UITableViewStyleInsetGrouped]; r.m = self.m; r.s = s; r.changed = changed; vc = r; }
    else return;
    vc.title = s.label; vc.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [self.navigationController pushViewController:vc animated:YES];
}
@end

// ---- the screen: game card on the left third, settings on the right two thirds ----
@interface DmLauncherVC : UIViewController
@property (strong) DmLauncherModel *m; @property (copy) void (^play)(void);
@end
@implementation DmLauncherVC
static id info(NSString *k) { return [NSBundle.mainBundle objectForInfoDictionaryKey:k]; }
static UIImage *app_icon(void) {
    UIImage *i = [UIImage imageNamed:@"AppIcon"]; if (i) return i;
    NSDictionary *icons = info(@"CFBundleIcons"); NSArray *files = [icons isKindOfClass:NSDictionary.class] ? icons[@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"] : nil;
    return [files isKindOfClass:NSArray.class] && [files.lastObject isKindOfClass:NSString.class] ? [UIImage imageNamed:files.lastObject] : nil;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    UIStackView *card = [UIStackView new]; card.axis = UILayoutConstraintAxisVertical; card.alignment = UIStackViewAlignmentCenter; card.spacing = 16;
    UIImage *icon = app_icon();
    if (icon) {
        UIImageView *iv = [[UIImageView alloc] initWithImage:icon]; iv.layer.cornerRadius = 22; iv.layer.cornerCurve = kCACornerCurveContinuous; iv.clipsToBounds = YES;
        iv.isAccessibilityElement = NO; [iv.widthAnchor constraintEqualToConstant:96].active = YES; [iv.heightAnchor constraintEqualToConstant:96].active = YES;
        [card addArrangedSubview:iv];
    }
    UILabel *name = [UILabel new]; name.text = [info(@"CFBundleDisplayName") isKindOfClass:NSString.class] ? info(@"CFBundleDisplayName") : @"Game";
    UIFontDescriptor *fd = [[UIFont preferredFontForTextStyle:UIFontTextStyleTitle1].fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    name.font = [UIFont fontWithDescriptor:fd size:0]; name.numberOfLines = 0; name.textAlignment = NSTextAlignmentCenter; [card addArrangedSubview:name];
    UILabel *ver = [UILabel new]; ver.text = [NSString stringWithFormat:@"Version %@", info(@"CFBundleShortVersionString") ?: @""];
    ver.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCallout]; ver.textColor = UIColor.secondaryLabelColor; [card addArrangedSubview:ver];
    UIButtonConfiguration *cfg = nil;
    SEL glass = NSSelectorFromString(@"prominentGlassButtonConfiguration");   // iOS 26's .glassProminent, as Launcher.swift; the filled style before it
    if ([UIButtonConfiguration respondsToSelector:glass]) cfg = ((UIButtonConfiguration *(*)(id, SEL))[UIButtonConfiguration methodForSelector:glass])(UIButtonConfiguration.class, glass);
    if (!cfg) cfg = [UIButtonConfiguration filledButtonConfiguration];
    cfg.buttonSize = UIButtonConfigurationSizeLarge;
    cfg.attributedTitle = [[NSAttributedString alloc] initWithString:@"Play" attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:[UIFont preferredFontForTextStyle:UIFontTextStyleTitle3].pointSize weight:UIFontWeightSemibold]}];
    __weak DmLauncherVC *w = self;
    UIButton *b = [UIButton buttonWithConfiguration:cfg primaryAction:[UIAction actionWithHandler:^(UIAction *a) { if (w.play) w.play(); }]];
    [b.widthAnchor constraintEqualToConstant:220].active = YES; [card addArrangedSubview:b];
    card.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:card];

    DmSettingsVC *list = [[DmSettingsVC alloc] initWithStyle:UITableViewStyleInsetGrouped]; list.m = self.m;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:list];
    [self addChildViewController:nav]; nav.view.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:nav.view]; [nav didMoveToParentViewController:self];
    UIView *v = self.view;
    UILayoutGuide *left = [UILayoutGuide new]; [v addLayoutGuide:left];   // the card is centered in the left third, 16 points from its edges
    [NSLayoutConstraint activateConstraints:@[
        [nav.view.topAnchor constraintEqualToAnchor:v.topAnchor], [nav.view.bottomAnchor constraintEqualToAnchor:v.bottomAnchor],
        [nav.view.trailingAnchor constraintEqualToAnchor:v.trailingAnchor], [nav.view.widthAnchor constraintEqualToAnchor:v.widthAnchor multiplier:2.0 / 3.0],
        [left.leadingAnchor constraintEqualToAnchor:v.leadingAnchor], [left.trailingAnchor constraintEqualToAnchor:nav.view.leadingAnchor],
        [card.centerXAnchor constraintEqualToAnchor:left.centerXAnchor], [card.centerYAnchor constraintEqualToAnchor:v.centerYAnchor],
        [card.widthAnchor constraintLessThanOrEqualToAnchor:left.widthAnchor constant:-32]]];
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskLandscape; }
- (BOOL)prefersStatusBarHidden { return YES; }
@end

bool dm_show_launcher(void *view_controller, void (*done)(void)) {
    const char *off = getenv("DM_LAUNCHER");
    if (off && !strcmp(off, "0")) { fprintf(stderr, "launcher: off (DM_LAUNCHER=0)\n"); return false; }
    NSString *path = [[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"dm"] stringByAppendingPathComponent:@"launcher.json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return false;
    NSArray<DmSetting *> *settings = load_settings(data);
    if (!settings.count) { fprintf(stderr, "[RED] launcher: dm/launcher.json cannot be read; starting the game\n"); return false; }
    UIViewController *parent = (__bridge UIViewController *)view_controller;
    DmLauncherModel *model = [[DmLauncherModel alloc] initWith:settings];
    DmLauncherVC *vc = [DmLauncherVC new]; vc.m = model; vc.modalPresentationStyle = UIModalPresentationFullScreen;
    __weak DmLauncherVC *wvc = vc; __block BOOL started = NO;
    vc.play = ^{
        if (started || !wvc) return;
        started = YES;
        [model apply];
        [wvc dismissViewControllerAnimated:NO completion:^{ done(); }];
    };
    [parent presentViewController:vc animated:NO completion:nil];
    fprintf(stderr, "launcher: %lu settings shown\n", (unsigned long)settings.count);
    return true;
}
