#!/usr/bin/env python3
# Windows replacement for dm/ios/tools/build_ipa.sh: the same unsigned all-in-one IPA (rewritten modules compiled into the executable, iOS shader libraries at DmIOS.app/msl,
# add-on content at DmIOS.app/aoc, the RomFS at DmIOS.app/romfs), built without Xcode:
#   xcodegen + xcodebuild   → LLVM clang (-target arm64-apple-ios26.0 -isysroot <iPhoneOS SDK>) per source file, linked by ld64.lld
#   Launcher.swift (SwiftUI) → win/ios/Launcher.m (UIKit, same dm_show_launcher contract), so no Swift toolchain is needed
#   actool (asset catalog)  → loose PNG icons named in CFBundleIcons (Pillow scales the game's icon.jpg)
#   sips / plutil           → Pillow / plistlib
#   make -n -B dmhost       → the source list of dm/host/Makefile, reproduced in host_sources() (checked against the Makefile text so an upstream change is noticed)
# Inputs: the same environment as build_ipa.sh (GAME, W, PATCHED, ROMFS, MSL_IOS, AOC, GFXAPI, DM_DISPLAY_NAME, DM_APP_VERSION, DM_BUNDLE_ID, DM_SHOW_FPS, DM_LANG, DM_ENV_FILE, DM_ICON, STD_FONT).
# Usage: win/build_app.py [output.ipa]   (--prepare-xcode is a Mac-only mode)
# It never signs: the sideloading tool (Sideloadly, AltStore, ...) signs the IPA, as with the upstream build.
import concurrent.futures as cf, hashlib, json, os, plistlib, re, shutil, subprocess, sys, time
from pathlib import Path
WIN = Path(__file__).resolve().parent
sys.path.insert(0, str(WIN))
import toolchain as tc

REPO = tc.REPO
DM = REPO / 'dm'
IOS = DM / 'ios'
HOST = DM / 'host'


def t(msg): print(f'[{time.strftime("%H:%M:%S")}] {msg}', flush=True)
def die(msg): t(f'FAIL: {msg}'); sys.exit(1)


def py(*args, env=None, capture=True):
    r = subprocess.run([sys.executable, *map(str, args)], capture_output=capture, text=True, env=env)
    if r.returncode: die(f'{Path(str(args[0])).name} {" ".join(map(str, args[1:]))}: {(r.stderr or r.stdout or "").strip()[-2000:]}')
    return (r.stdout or '').strip() if capture else ''


# ---- dm/host/Makefile, reproduced ----
def host_sources(game_h_dir):
    """(sources, include dirs) exactly as `make -n -B dmhost` lists them: SRC, GFX and the libvpx objects' sources; the include order of the host's link line, then libvpx's"""
    mk = (HOST / 'Makefile').read_text(encoding='utf-8')
    want_src = 'SRC=main.c loader.c hle.c crash.c probe.c thread.c memstat.m haptics_apple.m $(sort $(wildcard hle_*.c)) front_mac.m entry.S'
    want_gfx = 'GFX=$(sort $(wildcard ../gfx/*.c ../gfx/nvn/*.c ../gfx/nvn/*.m ../gfx/nvn/*.S ../gfx/tex/*.c ../gfx/tex/*.m ../gfx/vk/*.m ../gfx/gl/*.m))'
    for w in (want_src, want_gfx):
        if w not in mk: die(f'dm/host/Makefile changed ({w.split("=")[0]}= line): update host_sources() in win/build_app.py')
    src = [HOST / n for n in 'main.c loader.c hle.c crash.c probe.c thread.c memstat.m haptics_apple.m'.split()]
    src += sorted(HOST.glob('hle_*.c'), key=lambda p: p.name)
    src += [HOST / 'front_mac.m', HOST / 'entry.S']
    gfx = []
    for pat in ('../gfx/*.c', '../gfx/nvn/*.c', '../gfx/nvn/*.m', '../gfx/nvn/*.S', '../gfx/tex/*.c', '../gfx/tex/*.m', '../gfx/vk/*.m', '../gfx/gl/*.m'):
        d, g = pat.rsplit('/', 1)
        gfx += [(HOST / d / p.name) for p in (HOST / d).glob(g)]
    gfx = sorted(gfx, key=lambda p: os.path.relpath(p, HOST).replace('\\', '/'))   # make's $(sort) orders the words as text
    vpx = DM / 'third_party/libvpx'
    vpx_src = sorted(vpx.rglob('*.c'), key=lambda p: p.as_posix())
    incs = [DM / 'gfx/nvn/include', DM / 'third_party/vulkan-headers/include', game_h_dir, vpx, DM / 'third_party/stb_vorbis', vpx / 'config']
    files = []
    for s in src + gfx + vpx_src:
        s = s.resolve()
        if s.stem.endswith('_mac'): continue   # Mac-only sources (front_mac.m): front_ios.m implements front.h
        if s.parent == (IOS / 'Sources').resolve(): continue   # iOS sources the host borrows are compiled once, as iOS sources
        files.append(s)
    dirs = []
    for s in files:
        if s.parent not in dirs: dirs.append(s.parent)
    return files, [Path(i).resolve() for i in incs] + [d for d in dirs if d not in incs]


FRAMEWORKS_BASE = ['QuartzCore', 'Metal', 'GameController', 'CoreHaptics', 'AudioToolbox', 'VideoToolbox', 'CoreMedia', 'CoreVideo', 'ImageIO', 'UniformTypeIdentifiers',   # dm/host/Makefile minus Cocoa
                   'UIKit', 'Foundation', 'CoreGraphics', 'CoreFoundation']   # what the UIKit side and the launcher use (Xcode would add UIKit through Swift / module autolinking)
IMPORT = re.compile(r'^\s*#\s*(?:import|include)\s*<(\w+)/', re.M)


def frameworks(sdk, files):
    fw_dir = sdk / 'System/Library/Frameworks'
    out = list(FRAMEWORKS_BASE)
    for f in files:
        if f.suffix not in ('.m', '.c', '.h'): continue
        for name in IMPORT.findall(f.read_text(encoding='utf-8', errors='replace')):
            if name not in out and (fw_dir / f'{name}.framework').is_dir(): out.append(name)
    return [n for n in out if (fw_dir / f'{n}.framework').is_dir()]


# ---- compile + link ----
def compile_all(clang, sdk, files, incs, obj_dir, extra_defs):
    target = f'arm64-apple-ios{tc.setting("ios_deployment", tc.IOS_DEPLOYMENT)}'
    common = ['-target', target, '-isysroot', str(sdk), '-Os', '-mcpu=apple-a18', '-w', '-fno-common', '-DNS_BLOCK_ASSERTIONS=1', *extra_defs] + [f'-I{i}' for i in incs]
    obj_dir.mkdir(parents=True, exist_ok=True)
    jobs, objs = [], []
    for f in files:
        name = f.name
        if f == (HOST / 'main.c').resolve(): flags = common + ['-std=gnu11', '-Dmain=dm_main']   # the host's main, started by main.m (project.yml compilerFlags)
        elif f.suffix == '.c': flags = common + ['-std=gnu11']
        elif f.suffix == '.m': flags = common + ['-std=gnu11', '-fobjc-arc']
        elif f.suffix == '.S': flags = common
        else: continue
        key = hashlib.sha256((str(f) + '\0' + '\0'.join(flags)).encode()).hexdigest()[:12]
        o = obj_dir / f'{f.stem}-{key}.o'
        objs.append(o)
        if o.exists() and o.stat().st_mtime >= f.stat().st_mtime and not dep_newer(o): continue
        jobs.append((f, o, flags))
    t(f'compile: {len(jobs)} of {len(objs)} files (clang {target})')
    def one(j):
        f, o, flags = j
        d = o.with_suffix('.d')
        r = subprocess.run([str(clang), *flags, '-MMD', '-MF', str(d), '-c', str(f), '-o', str(o) + '.tmp'], capture_output=True, text=True)
        if r.returncode == 0: os.replace(str(o) + '.tmp', o)
        return f, r
    bad = []
    with cf.ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as ex:
        for i, (f, r) in enumerate(ex.map(one, jobs), 1):
            if r.returncode: bad.append((f, r.stderr))
            if i % 50 == 0 or i == len(jobs): t(f'compile: {i}/{len(jobs)}')
    if bad:
        for f, err in bad[:5]: print(f'---- {f}\n' + '\n'.join(l for l in err.splitlines() if 'error' in l)[:3000], file=sys.stderr)
        die(f'{len(bad)} file(s) did not compile')
    return objs


def dep_newer(o):
    """True when a header the object was built from (its .d file) is newer than the object"""
    d = o.with_suffix('.d')
    if not d.exists(): return True
    mt = o.stat().st_mtime
    text = d.read_text(errors='replace').replace('\\\n', ' ')
    for dep in re.split(r'(?<!\\)\s+', text.split(':', 1)[-1]):
        dep = dep.replace('\\ ', ' ').strip()
        if dep and os.path.exists(dep) and os.path.getmtime(dep) > mt: return True
    return False


def link(clang, sdk, objs, fws, embed_flags, out):
    target = f'arm64-apple-ios{tc.setting("ios_deployment", tc.IOS_DEPLOYMENT)}'
    args = [str(clang), '-target', target, '-isysroot', str(sdk), '-fuse-ld=lld', '-fobjc-arc', '-o', str(out), *map(str, objs),
            '-Wl,-rpath,@executable_path/Frameworks', '-lobjc', *[x for f in fws for x in ('-framework', f)], *embed_flags]
    rt = compat_rt_needed(clang)
    if rt: args.append(str(rt))
    t(f'link: {len(objs)} objects, {len(fws)} frameworks (ld64.lld)')
    r = subprocess.run(args, capture_output=True, text=True)
    if r.returncode: print(r.stderr[-6000:], file=sys.stderr); die('link failed')


def compat_rt_needed(clang):
    """LLVM for Windows ships no Darwin compiler-rt (libclang_rt.ios.a), which provides __isPlatformVersionAtLeast for @available; win/ios/compat_rt.c stands in for it"""
    r = subprocess.run([str(clang), '-print-resource-dir'], capture_output=True, text=True)
    res = Path(r.stdout.strip()) if r.returncode == 0 else None
    if res and list(res.glob('lib/darwin/libclang_rt.ios.a')): return None
    return WIN / 'build' / 'compat_rt.o'


# ---- bundle ----
def info_plist(bundle_id, name, version, category, show_fps, lang, sdk_ver, sdk_build, icons):
    p = {
        'CFBundleDevelopmentRegion': 'en', 'CFBundleExecutable': 'DmIOS', 'CFBundleIdentifier': bundle_id, 'CFBundleInfoDictionaryVersion': '6.0',
        'CFBundleName': 'DmIOS', 'CFBundleDisplayName': name, 'CFBundlePackageType': 'APPL', 'CFBundleShortVersionString': version, 'CFBundleVersion': version,
        'CFBundleSupportedPlatforms': ['iPhoneOS'], 'DTPlatformName': 'iphoneos', 'DTPlatformVersion': sdk_ver, 'DTSDKName': f'iphoneos{sdk_ver}', 'DTSDKBuild': sdk_build,
        'MinimumOSVersion': tc.setting('ios_deployment', tc.IOS_DEPLOYMENT), 'LSRequiresIPhoneOS': True, 'UIDeviceFamily': [1, 2], 'UIRequiredDeviceCapabilities': ['arm64'],
        # dm/ios/project.yml info.properties
        'UILaunchStoryboardName': '', 'UIFileSharingEnabled': True, 'LSSupportsOpeningDocumentsInPlace': True,
        'UISupportedInterfaceOrientations': ['UIInterfaceOrientationLandscapeRight', 'UIInterfaceOrientationLandscapeLeft'],
        'UISupportedInterfaceOrientations~ipad': ['UIInterfaceOrientationLandscapeRight', 'UIInterfaceOrientationLandscapeLeft'],
        'UIRequiresFullScreen': True, 'UIStatusBarHidden': True, 'UIViewControllerBasedStatusBarAppearance': False, 'LSApplicationCategoryType': category,
        'DMShowFPS': show_fps, 'DMLanguage': lang, 'LSSupportsGameMode': True, 'GCSupportsControllerUserInteraction': True,
        'GCSupportedGameControllers': [{'ProfileName': 'ExtendedGamepad'}], 'CADisableMinimumFrameDurationOnPhone': True,
        'UIApplicationSceneManifest': {'UIApplicationSupportsMultipleScenes': False, 'UISceneConfigurations': {'UIWindowSceneSessionRoleApplication': [
            {'UISceneConfigurationName': 'Default', 'UISceneDelegateClassName': 'SceneDelegate'}]}},
    }
    if icons:
        p['CFBundleIcons'] = {'CFBundlePrimaryIcon': {'CFBundleIconFiles': ['AppIcon60x60'], 'CFBundleIconName': 'AppIcon'}}
        p['CFBundleIcons~ipad'] = {'CFBundlePrimaryIcon': {'CFBundleIconFiles': ['AppIcon60x60', 'AppIcon76x76', 'AppIcon83.5x83.5'], 'CFBundleIconName': 'AppIcon'}}
    return p


ICONS = [('AppIcon60x60@2x.png', 120), ('AppIcon60x60@3x.png', 180), ('AppIcon76x76@2x~ipad.png', 152), ('AppIcon83.5x83.5@2x~ipad.png', 167), ('AppIcon.png', 1024)]


def make_icons(src, app):
    try: from PIL import Image
    except ImportError: t('no app icon: Pillow is not installed (pip install pillow); the home-screen icon stays blank'); return False
    im = Image.open(src).convert('RGB')
    for name, px in ICONS: im.resize((px, px), Image.LANCZOS).save(app / name, 'PNG')
    t(f'app icon: {src}')
    return True


def main():
    if len(sys.argv) > 1 and sys.argv[1] == '--prepare-xcode': die('--prepare-xcode makes an Xcode project: it needs a Mac (this Windows build packs the IPA directly)')
    env = os.environ
    game = env.get('GAME') or die('GAME is not set')
    w = Path(env.get('W') or die('W is not set: W=<NSP folder>/<title ID>-work'))
    sys.path.insert(0, str(DM / 'games')); import game as gm
    prof = gm.load(game)
    gd = prof.dir
    gp = lambda k: prof.get(k)
    if not (gd / 'game.tsv').exists(): die(f'no game profile {gd}/game.tsv')
    pkg = gp('package')
    patched = Path(env.get('PATCHED') or w / f'build/patched_{pkg}')
    romfs = Path(env.get('ROMFS') or w / f'data/{pkg}/RomFS')
    msl_ios = Path(env.get('MSL_IOS') or w / 'build/ios/dmsh_b')
    aoc = Path(env['AOC']) if env.get('AOC') else (None if 'AOC' in env else w / 'data/aoc')
    out_ipa = Path(sys.argv[1]) if len(sys.argv) > 1 else w.parent / gp('ipa')
    mods, marker = gp('modules').split(), gp('romfs_marker')
    nacp = w / 'data/v0/control.nacp'
    if not nacp.exists(): nacp = romfs.parent / 'control.nacp'
    vnacp = romfs.parent / 'control.nacp'
    if not vnacp.exists(): vnacp = w / 'data/v0/control.nacp'
    name = env.get('DM_DISPLAY_NAME') or py(DM / 'tools/nacp.py', nacp)
    r = subprocess.run([sys.executable, str(DM / 'tools/nacp.py'), '--version', str(vnacp)], capture_output=True, text=True)
    version = env.get('DM_APP_VERSION') or (r.stdout.strip() if r.returncode == 0 and r.stdout.strip() else '1.0')
    bundle_id = env.get('DM_BUNDLE_ID') or f'org.nxnative.{game.lower()}'
    show_fps = env.get('DM_SHOW_FPS', '0') in ('1', 'YES')
    lang = env.get('DM_LANG') or 'en-US'

    for m in mods:
        if not ((patched / f'{m}.patched.bin').exists() and (patched / f'{m}.fixups.tsv').exists()): die(f'no rewritten module {patched}/{m} (run dm/tools/patch_nso.py first)')
    if not (romfs / marker).exists(): die(f'no RomFS at {romfs} (missing {marker})')
    hdr = (DM / 'gfx/nvn/dmsh_chain.h').read_text(encoding='utf-8')
    v = (re.search(r'^#define DMSH_CHAIN "(.*)"', hdr, re.M) or die('no DMSH_CHAIN in dmsh_chain.h')).group(1)
    gfx = env.get('GFXAPI') or ('nvn' if list((msl_ios / f'b-{v}').glob('*_b.metallib')) else 'vulkan' if (msl_ios / 'vk/vk_shaders.metallib').exists()
                                else 'gl' if (msl_ios / 'gl/gl_shaders.metallib').exists() else 'nvn')
    if gfx == 'vulkan':
        if not (msl_ios / 'vk/vk_shaders.metallib').exists(): die(f'no iOS Vulkan shader library {msl_ios}/vk')
        msldir = 'vk'
    elif gfx == 'gl':
        if not (msl_ios / 'gl/gl_shaders.metallib').exists(): die(f'no iOS GL shader library {msl_ios}/gl')
        msldir = 'gl'
    else:
        msldir = f'b-{v}'
        if not list((msl_ios / msldir).glob('*_b.metallib')): die(f'no iOS shader libraries {msl_ios}/{msldir}')
        inputs = py(DM / 'gfx/tools/dmsh_chain.py', '--inputs', env=dict(env, DM_GAME=game))
        stamp = (msl_ios / msldir / 'inputs.tsv')
        lines = stamp.read_text(encoding='utf-8').splitlines() if stamp.exists() else []
        if f'game\t{game}' not in lines or f'inputs\t{inputs}' not in lines: die(f'the iOS shader libraries {msl_ios}/{msldir} are not a full build from this profile\'s current tables (inputs {inputs})')
        c1 = gd / 'c1_full.tsv'
        if not (c1.exists() and c1.read_text(encoding='utf-8').splitlines()[:1] and c1.read_text(encoding='utf-8').splitlines()[0].startswith(f'# chain b-{v} inputs {inputs} ')):
            die(f'{c1} is missing or not made from these libraries (chain {v}, inputs {inputs})')

    sdk = tc.ios_sdk() or die('no iPhoneOS SDK: set NXW_IOS_SDK (win/sdk/extract_xip.py extracts it from Xcode.xip)')
    clang = tc.llvm_tool('clang') or die('no clang: install LLVM for Windows (https://github.com/llvm/llvm-project/releases)')
    if not tc.llvm_tool('ld64.lld'): die('no ld64.lld in the LLVM folder')
    sdk_ver, sdk_build = tc.sdk_settings(sdk)
    t(f'app: {name} {version} ({bundle_id}), language {lang}{", frame-rate counter on" if show_fps else ""}; SDK {sdk.name} {sdk_ver} {sdk_build}')

    base = w / 'build/ios/win'
    gen, app = base / 'Gen', base / 'Payload/DmIOS.app'
    if gen.exists(): shutil.rmtree(gen)
    if app.exists(): shutil.rmtree(app)
    (gen / 'profile').mkdir(parents=True); app.mkdir(parents=True)
    t('generate Gen/ (profile header, embedded modules, tables)')
    py(DM / 'games/game.py', 'header', game, gen / 'profile/game_profile.h')
    flags = py(IOS / 'tools/gen_embed.py', patched, gen / 'embed.S', *mods)
    es = gen / 'embed.S'
    es.write_text(re.sub(r'\.incbin "([^"]*)"', lambda m: '.incbin "' + m.group(1).replace('\\', '/') + '"', es.read_text(encoding='utf-8')), encoding='utf-8')   # assembler strings take \ as an escape

    dmres = app / 'dm'; dmres.mkdir()
    for pat in ('*.fixups.tsv', '*.gates.tsv', '*.cuts.tsv', '*.obs.tsv'):
        for f in patched.glob(pat): shutil.copy2(f, dmres)
    if (patched / 'nro.tsv').exists(): shutil.copy2(patched / 'nro.tsv', dmres)
    for f in ('shader_map.tsv', 'pso_manifest.tsv') + (() if gfx in ('vulkan', 'gl') else ('c1_full.tsv',)):
        shutil.copy2(gd / f, dmres)
    if gfx == 'nvn':
        if (gd / 'cb_extent.tsv').exists(): shutil.copy2(gd / 'cb_extent.tsv', dmres)
        else: t(f'no {gd}/cb_extent.tsv: the host copies whole uniform bindings')
    t('launcher: ' + py(DM / 'games/settings.py', game, patched, vnacp, dmres / 'launcher.json', env=dict(env, GFXAPI=gfx)))
    if env.get('DM_ENV_FILE'): shutil.copy2(env['DM_ENV_FILE'], dmres / 'env.txt')
    (dmres / 'font').mkdir()
    font = tc.std_font() or die('no standard font: set STD_FONT to a TTF with broad Unicode coverage')
    shutil.copy2(font, dmres / 'font/standard.ttf'); t(f'standard font: {font}')
    py(DM / 'tools/make_ext_font.py', dmres / 'font/nintendo_ext.ttf', tc.letter_font() or die('no bold TTF for the button icons: set LETTER_FONT'))

    files, incs = host_sources(gen / 'profile')
    files += [p.resolve() for p in sorted((IOS / 'Sources').glob('*.m'))] + [(WIN / 'ios/Launcher.m').resolve(), es.resolve()]
    fws = frameworks(sdk, files)
    rt = compat_rt_needed(clang)
    if rt:
        rt.parent.mkdir(parents=True, exist_ok=True)
        r = subprocess.run([str(clang), '-target', f'arm64-apple-ios{tc.IOS_DEPLOYMENT}', '-isysroot', str(sdk), '-Os', '-c', str(WIN / 'ios/compat_rt.c'), '-o', str(rt)], capture_output=True, text=True)
        if r.returncode: print(r.stderr, file=sys.stderr); die('compat_rt.c')
    objs = compile_all(clang, sdk, files, incs, base / 'obj', [])
    link(clang, sdk, objs, fws, flags.split(), app / 'DmIOS')

    icon = Path(env.get('DM_ICON') or romfs.parent / 'icon.jpg')
    icons = icon.exists() and make_icons(icon, app)
    if not icon.exists(): t(f'no app icon ({icon} not found): the home-screen icon stays blank')
    with open(app / 'Info.plist', 'wb') as f:
        plistlib.dump(info_plist(bundle_id, name, version, gp('app_category'), show_fps, lang, sdk_ver, sdk_build, icons), f, fmt=plistlib.FMT_BINARY)
    (app / 'PkgInfo').write_bytes(b'APPL????')

    maps = [f'Payload/DmIOS.app={app}', f'Payload/DmIOS.app/msl/{msldir}={msl_ios / msldir}']
    if aoc and aoc.is_dir() and any(aoc.iterdir()): maps.append(f'Payload/DmIOS.app/aoc={aoc}'); t('add-on content: ' + ' '.join(sorted(p.name for p in aoc.iterdir())))
    maps.append(f'Payload/DmIOS.app/romfs={romfs}')
    t('pack IPA (already-compressed game files stored, everything else deflated)')
    r = subprocess.run([sys.executable, str(IOS / 'tools/pack_ipa.py'), str(out_ipa), '--store', ':'.join(gp('zip_store').split(':')),
                        '--exec', 'Payload/DmIOS.app/DmIOS', '--skip', 'Payload/DmIOS.app/msl', '--skip', 'Payload/DmIOS.app/aoc', '--skip', 'Payload/DmIOS.app/romfs', *maps])
    if r.returncode: die('pack_ipa')
    t(f'done: {out_ipa} ({out_ipa.stat().st_size / 2**30:.1f} GB)')


if __name__ == '__main__':
    main()
