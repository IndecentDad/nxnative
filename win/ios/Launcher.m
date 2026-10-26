// Launcher for the Windows build: a UIKit port of dm/ios/Sources/Launcher.swift (SwiftUI), so the app builds with clang alone (no Swift toolchain).
// Its look follows the SwiftUI launcher's Form (upstream 2f69480): the game card on the left half; on the right half every setting in a section of its own
// (a separate rounded row, its note as the section footer), choices as a menu button, ranges as an inline slider with a percentage, toggles as switches,
// and the memory available. Same contract: dm_show_launcher(view controller, done) shows the screen over the root view controller, puts every setting into
// the environment when Play is pressed and then calls done; it returns false (done is not called) when there is no launcher (no dm/launcher.json,
// DM_LAUNCHER=0, or a file it cannot read). Settings come from the app's dm/launcher.json (dm/games/settings.py): kind "choice" (options [[value, label]]),
// "range" (min / max / step, shown as a percentage) or a toggle ("1" / "0"). A variable an env file set (DM_ENV_FILE_KEYS, main.m) is shown but kept.
// Choices are kept in NSUserDefaults under "launcher.<ENV>", as the Swift launcher does.
#import <UIKit/UIKit.h>
#include <os/proc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

@interface DmSetting : NSObject
@property (copy) NSString *env, *kind, *label, *note, *def;
@property (copy) NSArray<NSArray<NSString *> *> *options;   // choice: [value, label]
@property double min, max, step; @property BOOL hasMin, hasMax, hasStep;
@property BOOL disabled;   // listed for every game, but this one has nothing it acts on (settings.tsv always/<condition>): shown greyed out, never applied
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
        s.disabled = [d[@"disabled"] isKindOfClass:NSNumber.class] && [d[@"disabled"] boolValue];
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
- (BOOL)locked:(DmSetting *)s { return s.disabled || [self.fromFile containsObject:s.env]; }
- (NSString *)note:(DmSetting *)s {
    if (s.disabled || ![self.fromFile containsObject:s.env]) return s.note;
    return [NSString stringWithFormat:@"%@Set by an env file", s.note.length ? [s.note stringByAppendingString:@" · "] : @""];
}
- (double)rangeValue:(DmSetting *)s {
    NSString *v = [self value:s]; NSScanner *sc = [NSScanner scannerWithString:v]; double d;
    return ([sc scanDouble:&d] && sc.isAtEnd) ? d : (s.hasMax ? s.max : 1);
}
- (NSString *)percentage:(DmSetting *)s { return [NSString stringWithFormat:@"%ld %%", lround([self rangeValue:s] * 100)]; }
- (NSString *)choiceLabel:(DmSetting *)s {
    NSString *cur = [self value:s];
    for (NSArray *o in s.options) if ([o[0] isEqualToString:cur]) return o[1];
    return cur;
}
- (void)apply {   // before the game starts: every setting not set by an env file goes into the environment (DM_LANG replaces the packed language main.m set as a default)
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    for (DmSetting *s in self.settings) {
        NSString *v = [self value:s];
        if (s.disabled) continue;   // nothing in this game reads it
        if ([self locked:s]) { fprintf(stderr, "launcher: %s kept at %s (env file)\n", s.env.UTF8String, v.UTF8String); continue; }
        [ud setObject:v forKey:[@"launcher." stringByAppendingString:s.env]];
        setenv(s.env.UTF8String, v.UTF8String, 1); fprintf(stderr, "launcher: %s=%s\n", s.env.UTF8String, v.UTF8String);
    }
}
@end

static UILabel *body_label(NSString *text) {
    UILabel *l = [UILabel new]; l.text = text; l.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody]; l.textColor = UIColor.labelColor;
    l.translatesAutoresizingMaskIntoConstraints = NO; [l setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    return l;
}

static UILabel *value_label(NSString *text) {
    UILabel *l = [UILabel new]; l.text = text; l.textColor = UIColor.secondaryLabelColor; l.textAlignment = NSTextAlignmentRight;
    l.font = [UIFont monospacedDigitSystemFontOfSize:[UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize weight:UIFontWeightRegular];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    return l;
}

// ---- the settings: one section per setting, as SwiftUI's Form draws a Section per row ----
@interface DmSettingsVC : UITableViewController
@property (strong) DmLauncherModel *m; @property (strong) NSTimer *timer; @property (strong) UILabel *memory;
@end
@implementation DmSettingsVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.rowHeight = UITableViewAutomaticDimension; self.tableView.estimatedRowHeight = 56;
    self.tableView.sectionHeaderTopPadding = 0;
    __weak DmSettingsVC *w = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *t) { w.memory.text = [NSByteCountFormatter stringFromByteCount:(long long)os_proc_available_memory() countStyle:NSByteCountFormatterCountStyleMemory]; }];
}
- (void)dealloc { [self.timer invalidate]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return self.m.settings.count + 1; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec { return 1; }
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)sec { return sec == 0 ? 20 : 12; }
- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)sec { return [UIView new]; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)sec {
    if (sec >= (NSInteger)self.m.settings.count) return nil;
    NSString *n = [self.m note:self.m.settings[sec]]; return n.length ? n : nil;
}
- (CGFloat)tableView:(UITableView *)tv heightForFooterInSection:(NSInteger)sec {
    if (sec < (NSInteger)self.m.settings.count && [self.m note:self.m.settings[sec]].length) return UITableViewAutomaticDimension;
    return 12;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    c.selectionStyle = UITableViewCellSelectionStyleNone;
    UIView *v = c.contentView; UILayoutGuide *g = v.layoutMarginsGuide;
    if (ip.section == (NSInteger)self.m.settings.count) {   // Memory available
        UILabel *l = body_label(@"Memory available");
        self.memory = value_label([NSByteCountFormatter stringFromByteCount:(long long)os_proc_available_memory() countStyle:NSByteCountFormatterCountStyleMemory]);
        [v addSubview:l]; [v addSubview:self.memory];
        [NSLayoutConstraint activateConstraints:@[[l.leadingAnchor constraintEqualToAnchor:g.leadingAnchor], [l.centerYAnchor constraintEqualToAnchor:v.centerYAnchor],
            [self.memory.trailingAnchor constraintEqualToAnchor:g.trailingAnchor], [self.memory.centerYAnchor constraintEqualToAnchor:v.centerYAnchor],
            [v.heightAnchor constraintGreaterThanOrEqualToConstant:56]]];
        return c;
    }
    DmSetting *s = self.m.settings[ip.section]; BOOL locked = [self.m locked:s];
    UILabel *l = body_label(s.label); [v addSubview:l];
    NSMutableArray *cs = [@[[l.leadingAnchor constraintEqualToAnchor:g.leadingAnchor], [l.centerYAnchor constraintEqualToAnchor:v.centerYAnchor],
                            [v.heightAnchor constraintGreaterThanOrEqualToConstant:56]] mutableCopy];
    if ([s.kind isEqualToString:@"choice"]) {   // SwiftUI's default Picker in a Form: the value with up / down chevrons, opening a menu
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.title = [self.m choiceLabel:s]; cfg.baseForegroundColor = UIColor.secondaryLabelColor;
        cfg.image = [UIImage systemImageNamed:@"chevron.up.chevron.down" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold]];
        cfg.imagePlacement = NSDirectionalRectEdgeTrailing; cfg.imagePadding = 5; cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 0);
        cfg.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *a) { NSMutableDictionary *m = [a mutableCopy]; m[NSFontAttributeName] = [UIFont preferredFontForTextStyle:UIFontTextStyleBody]; return m; };
        UIButton *b = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
        b.showsMenuAsPrimaryAction = YES; b.changesSelectionAsPrimaryAction = NO; b.enabled = !locked;
        b.menu = [self menuFor:s button:b];
        b.translatesAutoresizingMaskIntoConstraints = NO; [v addSubview:b];
        [cs addObjectsFromArray:@[[b.trailingAnchor constraintEqualToAnchor:g.trailingAnchor], [b.centerYAnchor constraintEqualToAnchor:v.centerYAnchor],
                                  [b.leadingAnchor constraintGreaterThanOrEqualToAnchor:l.trailingAnchor constant:12]]];
    } else if ([s.kind isEqualToString:@"range"]) {   // label, slider, percentage in one row
        UISlider *sl = [UISlider new]; sl.translatesAutoresizingMaskIntoConstraints = NO;
        sl.minimumValue = s.hasMin ? s.min : 0; sl.maximumValue = s.hasMax ? s.max : 1; sl.value = [self.m rangeValue:s];
        sl.enabled = !locked; sl.accessibilityLabel = s.label; sl.tag = ip.section;
        [sl addTarget:self action:@selector(slid:) forControlEvents:UIControlEventValueChanged];
        UILabel *pct = value_label([self.m percentage:s]); pct.tag = 1000 + ip.section;
        [v addSubview:sl]; [v addSubview:pct];
        [cs addObjectsFromArray:@[[sl.leadingAnchor constraintEqualToAnchor:l.trailingAnchor constant:12], [sl.centerYAnchor constraintEqualToAnchor:v.centerYAnchor],
                                  [pct.leadingAnchor constraintEqualToAnchor:sl.trailingAnchor constant:12], [pct.widthAnchor constraintEqualToConstant:56],
                                  [pct.trailingAnchor constraintEqualToAnchor:g.trailingAnchor], [pct.centerYAnchor constraintEqualToAnchor:v.centerYAnchor]]];
    } else {
        UISwitch *sw = [UISwitch new]; sw.on = [[self.m value:s] isEqualToString:@"1"]; sw.enabled = !locked; sw.tag = ip.section;
        sw.translatesAutoresizingMaskIntoConstraints = NO;
        [sw addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
        [v addSubview:sw];
        [cs addObjectsFromArray:@[[sw.trailingAnchor constraintEqualToAnchor:g.trailingAnchor], [sw.centerYAnchor constraintEqualToAnchor:v.centerYAnchor]]];
    }
    [NSLayoutConstraint activateConstraints:cs];
    if (locked) l.textColor = UIColor.tertiaryLabelColor;
    return c;
}

- (UIMenu *)menuFor:(DmSetting *)s button:(UIButton *)b {
    NSMutableArray *items = [NSMutableArray array];
    NSString *cur = [self.m value:s];
    __weak DmSettingsVC *w = self; __weak UIButton *wb = b;
    for (NSArray *o in s.options) {
        UIAction *a = [UIAction actionWithTitle:o[1] image:nil identifier:nil handler:^(UIAction *act) {
            DmSettingsVC *me = w; if (!me) return;
            me.m.values[s.env] = o[0];
            UIButtonConfiguration *cfg = wb.configuration; cfg.title = o[1]; wb.configuration = cfg;
            wb.menu = [me menuFor:s button:wb];
        }];
        a.state = [o[0] isEqualToString:cur] ? UIMenuElementStateOn : UIMenuElementStateOff;
        [items addObject:a];
    }
    return [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsSingleSelection children:items];
}

- (void)slid:(UISlider *)sl {
    DmSetting *s = self.m.settings[sl.tag];
    double step = s.hasStep ? s.step : 0.05, lo = s.hasMin ? s.min : 0;
    double v = step > 0 ? lo + round((sl.value - lo) / step) * step : sl.value;   // SwiftUI's Slider(step:) snaps the same way
    self.m.values[s.env] = [NSString stringWithFormat:@"%.2f", v];
    UILabel *pct = [sl.superview viewWithTag:1000 + sl.tag];
    pct.text = [self.m percentage:s]; sl.accessibilityValue = pct.text;
}
- (void)toggled:(UISwitch *)sw { DmSetting *s = self.m.settings[sw.tag]; self.m.values[s.env] = sw.on ? @"1" : @"0"; }
@end

// ---- the screen: game card on the left half, settings on the right half ----
@interface DmLauncherVC : UIViewController
@property (strong) DmLauncherModel *m; @property (copy) void (^play)(void);
@end
@implementation DmLauncherVC
static id info(NSString *k) { return [NSBundle.mainBundle objectForInfoDictionaryKey:k]; }
static UIImage *app_icon(void) {
    UIImage *i = [UIImage imageNamed:@"AppIcon"]; if (i) return i;
    NSDictionary *icons = info(@"CFBundleIcons"); NSArray *files = [icons isKindOfClass:NSDictionary.class] ? icons[@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"] : nil;
    for (NSString *f in [files reverseObjectEnumerator]) { UIImage *im = [f isKindOfClass:NSString.class] ? [UIImage imageNamed:f] : nil; if (im) return im; }
    return [UIImage imageNamed:@"AppIcon60x60"];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = UIColor.blackColor;
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
    cfg.buttonSize = UIButtonConfigurationSizeLarge; cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    UIFontDescriptor *pd = [[UIFont preferredFontForTextStyle:UIFontTextStyleTitle3].fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    cfg.attributedTitle = [[NSAttributedString alloc] initWithString:@"Play" attributes:@{NSFontAttributeName: [UIFont fontWithDescriptor:pd size:0]}];
    __weak DmLauncherVC *w = self;
    UIButton *b = [UIButton buttonWithConfiguration:cfg primaryAction:[UIAction actionWithHandler:^(UIAction *a) { if (w.play) w.play(); }]];
    [b.widthAnchor constraintEqualToConstant:220].active = YES; [card addArrangedSubview:b];
    [card setCustomSpacing:20 afterView:ver];
    card.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:card];

    DmSettingsVC *list = [[DmSettingsVC alloc] initWithStyle:UITableViewStyleInsetGrouped]; list.m = self.m;
    [self addChildViewController:list]; list.view.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:list.view]; [list didMoveToParentViewController:self];
    UIView *v = self.view;
    UILayoutGuide *left = [UILayoutGuide new]; [v addLayoutGuide:left];   // two equal halves, as the SwiftUI HStack of two maxWidth: .infinity views
    [NSLayoutConstraint activateConstraints:@[
        [list.view.topAnchor constraintEqualToAnchor:v.topAnchor], [list.view.bottomAnchor constraintEqualToAnchor:v.bottomAnchor],
        [list.view.trailingAnchor constraintEqualToAnchor:v.safeAreaLayoutGuide.trailingAnchor], [list.view.widthAnchor constraintEqualToAnchor:v.safeAreaLayoutGuide.widthAnchor multiplier:0.5],
        [left.leadingAnchor constraintEqualToAnchor:v.safeAreaLayoutGuide.leadingAnchor], [left.trailingAnchor constraintEqualToAnchor:list.view.leadingAnchor],
        [card.centerXAnchor constraintEqualToAnchor:left.centerXAnchor], [card.centerYAnchor constraintEqualToAnchor:v.centerYAnchor],
        [card.widthAnchor constraintLessThanOrEqualToAnchor:left.widthAnchor constant:-48]]];
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskLandscape; }
- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
@end

// A capture IPA (win/build_ipa_windows.py: the run-time shader capture done on the device instead of a Mac) sets DM_GLSLC_CAPTURE / DM_VK_CAPTURE / DM_GL_CAPTURE in its dm/env.txt
// to a folder relative to Documents (main.m makes Documents the working directory); the Vulkan and GL captures write into the folder without making it, so it is made here, before the game starts
static void make_capture_folders(void) {
    static const char *const keys[] = {"DM_GLSLC_CAPTURE", "DM_VK_CAPTURE", "DM_GL_CAPTURE"};
    for (int i = 0; i < 3; i++) {
        const char *k = keys[i], *d = getenv(k);
        if (d && *d) { [NSFileManager.defaultManager createDirectoryAtPath:@(d) withIntermediateDirectories:YES attributes:nil error:nil]; fprintf(stderr, "capture: %s → Documents/%s\n", k, d); }
    }
}

bool dm_show_launcher(void *view_controller, void (*done)(void)) {
    make_capture_folders();
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
