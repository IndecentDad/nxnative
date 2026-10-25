# Windows toolchain locator for the nxnative Windows port.
# Every Apple tool the upstream pipeline calls (xcrun metal / metallib / clang, xcodebuild, sips, ...) is mapped to a Windows equivalent here:
#   Metal compiler      Apple's "Metal Developer Tools for Windows" (metal.exe / metallib.exe, separate ios and macos toolchains)
#   C / ObjC / asm      LLVM for Windows (clang.exe + ld64.lld.exe), targeting arm64-apple-ios with an iPhoneOS SDK taken from Xcode.xip (win/sdk/extract_xip.py)
#   shader translator   the committed .NET DLLs in dm/gfx/tools/dmsh_xlate_bin, run with `dotnet dmsh_xlate.dll` (the Mach-O apphost next to them cannot run here)
# Paths come from environment variables first, then win/toolchain.json (see win/toolchain.example.json), then well-known install locations.
import glob, json, os, plistlib, shutil, sys
from pathlib import Path

WIN = Path(__file__).resolve().parent
REPO = WIN.parent
CONFIG = WIN / 'toolchain.json'

# Deployment targets: the iOS one matches dm/ios/project.yml (Metal 4 needs iOS 26); shaders keep ios_metal.py's -mios-version-min=18.0
IOS_DEPLOYMENT = '26.0'
METAL_MACOS_TARGET = '15.0'   # the Mac shader libraries only feed the Mac-side reflection checks; Xcode's default would be the SDK version


def _cfg():
    try: return json.loads(CONFIG.read_text(encoding='utf-8'))
    except FileNotFoundError: return {}
    except ValueError as e: sys.exit(f'[RED] {CONFIG}: {e}')


def setting(key, default=None):
    """NXW_<KEY> in the environment, else <key> in win/toolchain.json, else default"""
    v = os.environ.get('NXW_' + key.upper())
    if v: return v
    return _cfg().get(key, default)


def _first(paths):
    for p in paths:
        if p and Path(p).exists(): return Path(p)
    return None


def metal_tools_root():
    """The Metal Developer Tools for Windows install folder (holds ios/ and macos/ toolchains)"""
    cands = [setting('metal_tools')]
    for base in (os.environ.get('ProgramFiles', r'C:\Program Files'), os.environ.get('ProgramFiles(x86)', r'C:\Program Files (x86)')):
        cands += sorted(glob.glob(os.path.join(base, 'Metal Developer Tools*')), reverse=True)
    return _first(cands)


def metal_tool(sdk, name):
    """metal.exe / metallib.exe of the iOS (sdk iphoneos) or macOS (sdk macosx) toolchain"""
    root = metal_tools_root()
    if not root: return None
    sub = 'ios' if sdk.startswith('iphone') else 'macos'
    # 4.x shipped one toolchain per OS (ios/, macos/); 5.x and 6.x ship one for every target in bin/ (the -target triple picks the OS)
    for pat in (f'{sub}/bin/{name}.exe', f'{sub}/**/bin/{name}.exe', f'**/{sub}/**/{name}.exe', f'bin/{name}.exe'):
        hits = sorted(glob.glob(str(root / pat), recursive=True))
        if hits: return Path(hits[0])
    return None


def llvm_bin():
    cands = [setting('llvm')]
    for base in (os.environ.get('ProgramFiles', r'C:\Program Files'),):
        cands.append(os.path.join(base, 'LLVM'))
    root = _first(cands)
    if root and (root / 'bin').is_dir(): return root / 'bin'
    c = shutil.which('clang')
    return Path(c).parent if c else None


def llvm_tool(name):
    b = llvm_bin()
    if b and (b / f'{name}.exe').exists(): return b / f'{name}.exe'
    w = shutil.which(name)
    return Path(w) if w else None


def ios_sdk():
    """The iPhoneOS SDK folder (iPhoneOS<ver>.sdk, from Xcode.xip via win/sdk/extract_xip.py)"""
    cands = [setting('ios_sdk')]
    cands += sorted(glob.glob(str(WIN / 'sdk' / 'out' / '**' / 'iPhoneOS*.sdk'), recursive=True), reverse=True)
    return _first(cands)


def sdk_settings(sdk):
    """(version, build version) of an SDK folder, from SDKSettings.json / SDKSettings.plist and System/Library/CoreServices/SystemVersion.plist"""
    ver = build = ''
    js = Path(sdk) / 'SDKSettings.json'
    if js.exists():
        try: ver = json.loads(js.read_text(encoding='utf-8')).get('Version', '')
        except ValueError: pass
    pl = Path(sdk) / 'SDKSettings.plist'
    if not ver and pl.exists():
        with open(pl, 'rb') as f: ver = plistlib.load(f).get('Version', '')
    sv = Path(sdk) / 'System/Library/CoreServices/SystemVersion.plist'
    if sv.exists():
        with open(sv, 'rb') as f: build = plistlib.load(f).get('ProductBuildVersion', '')
    return ver, build


def dotnet():
    w = shutil.which('dotnet')
    return Path(w) if w else None


def xlate_dll():
    return REPO / 'dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate.dll'


def tool_on_path(name):
    """A Windows build of a cross-platform tool (spirv-cross, glslangValidator, zstd): win/toolchain.json may name its folder"""
    d = setting(name.replace('-', '_') + '_dir')
    if d:
        p = Path(d) / f'{name}.exe'
        if p.exists(): return p
    w = shutil.which(name)
    return Path(w) if w else None


def letter_font():
    """The letters of the button-icon font (make_ext_font.py; upstream: macOS's Arial Rounded Bold): LETTER_FONT, toolchain.json letter_font, else Windows' Arial Rounded MT Bold or Arial Bold"""
    fonts = Path(os.environ.get('WINDIR', r'C:\Windows')) / 'Fonts'
    return _first([os.environ.get('LETTER_FONT'), setting('letter_font'), fonts / 'ARLRDBD.TTF', fonts / 'arialbd.ttf', fonts / 'arial.ttf'])


def std_font():
    """The shared-font stand-in (standard.ttf). Upstream copies macOS's Arial Unicode; on Windows: STD_FONT, toolchain.json std_font, else a broad-coverage Windows font"""
    windir = os.environ.get('WINDIR', r'C:\Windows')
    return _first([os.environ.get('STD_FONT'), setting('std_font'), os.path.join(windir, 'Fonts', 'ARIALUNI.TTF'), os.path.join(windir, 'Fonts', 'arial.ttf')])
