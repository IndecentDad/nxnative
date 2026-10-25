#!/usr/bin/env python3
# NSP → IPA on Windows: runs the upstream pipeline (scripts/build_ipa_from_nsp.py) unchanged, with its macOS-only steps replaced:
#   check_prereqs        → the Windows toolchain (win/doctor.py)
#   build_nx_extract     → the same dotnet build, which on Windows writes nx_extract.exe
#   can_clone            → False (no APFS clones; nx_extract writes plain copies)
#   toolchain()          → the Windows Metal compiler's and spirv-cross's versions (shader cache keys)
#   build_ipa.sh         → win/build_app.py (through win/pyshim/sitecustomize.py, which also maps xcrun / dmsh_xlate / which)
#   Mac host steps       → refused with a clear message: games whose shaders exist only at run time (GLSLC / Vulkan / GL capture, Unreal and Oodle decoding)
#                          boot the game's own arm64 code in the Mac host, which no Windows PC can run
# Usage: python win/build_ipa_windows.py <NSP folder> -k <prod.keys> [the upstream script's other options]   (--platform mac / mac-app and --prepare-xcode are Mac-only)
import importlib.util, os, subprocess, sys
from pathlib import Path

WIN = Path(__file__).resolve().parent
REPO = WIN.parent
SHIM = WIN / 'pyshim'


def main():
    if os.name != 'nt': sys.exit('win/build_ipa_windows.py is the Windows driver: on a Mac run scripts/build_ipa_from_nsp.py')
    for bad in ('--prepare-xcode',):
        if bad in sys.argv: sys.exit(f'{bad} needs a Mac with Xcode')
    for i, a in enumerate(sys.argv):
        if (a == '--platform' and i + 1 < len(sys.argv) and sys.argv[i + 1] != 'ios') or (a.startswith('--platform=') and a != '--platform=ios'):
            sys.exit('only --platform ios builds on Windows (the Mac platforms run the game in the Mac host)')
    # every Python the pipeline starts loads the shim; this one too
    os.environ['PYTHONPATH'] = os.pathsep.join([str(SHIM)] + [p for p in os.environ.get('PYTHONPATH', '').split(os.pathsep) if p])
    os.environ.setdefault('PYTHONUTF8', '1')   # the pipeline reads and writes UTF-8 text without naming the encoding
    # Windows builds get their own bundle IDs (org.nxnativewindows.<title ID>), so they install beside a Mac-built IPA of the same game; --bundle-id still names any ID
    if not any(a == '--bundle-id' or a.startswith('--bundle-id=') for a in sys.argv):
        sys.path.insert(0, str(WIN)); import toolchain as _tc
        os.environ['NXW_BUNDLE_PREFIX'] = _tc.setting('bundle_prefix', 'org.nxnativewindows')
    sys.path.insert(0, str(SHIM)); import sitecustomize  # noqa: F401
    sys.path.insert(0, str(WIN)); import toolchain as tc, doctor

    spec = importlib.util.spec_from_file_location('build_ipa_from_nsp', REPO / 'scripts/build_ipa_from_nsp.py')
    up = importlib.util.module_from_spec(spec); sys.modules['build_ipa_from_nsp'] = up; spec.loader.exec_module(up)
    BuildError = up.BuildError

    extra = [str(p) for p in (tc.llvm_bin(),) if p] + [str(tc.tool_on_path(t).parent) for t in ('spirv-cross', 'zstd', 'glslangValidator') if tc.tool_on_path(t)]
    up.TOOL_PATHS = extra + [str(Path(os.environ.get('ProgramFiles', r'C:\Program Files')) / 'dotnet')]

    def check_prereqs(env, xlate, mac=False):
        if mac: raise BuildError('the Mac platforms need a Mac')
        bad = [r for r in doctor.checks() if r['required'] and not r['ok']]
        if bad: raise BuildError('missing on this PC: ' + '; '.join(f'{r["name"]} ({r["how"]})' for r in bad) + ' (python win/doctor.py lists them)')
        if not xlate.parent.is_dir(): raise BuildError(f'the shader translator is missing from the repository: {xlate}')
    up.check_prereqs = check_prereqs

    def build_nx_extract(repo, work, logs, env):
        import tempfile, shutil
        nx = work / 'tools/nx_extract/nx_extract'
        with tempfile.TemporaryDirectory(prefix='nx_extract_') as t:
            up.run(['dotnet', 'build', repo / 'dm/tools/nx_extract', '-c', 'Release', '-o', t, '-v', 'quiet', '-nologo'], logs / 'nx_extract_build.log', env=env)
            if not (Path(t) / 'nx_extract.exe').exists(): raise BuildError(f'nx_extract built without an executable (see {logs / "nx_extract_build.log"})')
            up.rmtree(nx.parent); shutil.copytree(t, nx.parent)
        return nx   # Windows starts nx_extract.exe for this path
    up.build_nx_extract = build_nx_extract

    up.can_clone = lambda d: False
    up.apple_silicon = lambda: False
    xc = [sys.executable, str(WIN / 'xcrun.py')]
    up.toolchain = lambda: (('cmd', xc + ['-sdk', 'iphoneos', 'metal', '--version']), ('cmd', xc + ['-sdk', 'macosx', 'metal', '--version']), ('cmd', ['spirv-cross', '--revision']))

    def mac_only(what):
        def refuse(*a, **k):
            raise BuildError(f'{what}: this game makes some shaders only at run time, and getting them boots the game\'s own arm64 code in the Mac host. '
                             'That needs a Mac with Apple silicon; build this game on one (or move only this step there), the rest of the pipeline runs here')
        return refuse
    for fn, what in (('build_mac_host', 'the Mac host'), ('capture_glslc', 'GLSLC capture'), ('capture_shaders', 'run-time shader capture'), ('decode_ue_shaders', 'Unreal shader decoding')):
        if hasattr(up, fn): setattr(up, fn, mac_only(what))

    derive = up.derive_profile
    def derive_profile(g, pdir, ver, d, mods, app=None):
        """upstream's derived profile, with a RomFS marker this version has: the profile's marker may be a file only its tested version ships (Balatro 1.1.3's NotoSansSC-Bold.ttf,
        absent from v0), and both the IPA build and the app's start (main.m romfs_locate) look for it. Then main.lua (LÖVE) or the largest RomFS file stands in"""
        disp = derive(g, pdir, ver, d, mods, app)
        tsv = pdir / 'game.tsv'; T = '\t'
        lines = tsv.read_text(encoding='utf-8').splitlines()
        old = next((l.split(T, 1)[1] for l in lines if l.startswith('romfs_marker' + T)), None)
        romfs = d / 'RomFS'
        if old and not (romfs / old).exists():
            files = [p for p in romfs.rglob('*') if p.is_file()]
            new = 'main.lua' if (romfs / 'main.lua').exists() else os.path.relpath(max(files, key=lambda p: p.stat().st_size), romfs).replace('\\', '/') if files else None
            if new:
                tsv.write_text('\n'.join(f'romfs_marker{T}{new}' if l.startswith('romfs_marker' + T) else l for l in lines) + '\n', encoding='utf-8')
                up.say(f'romfs_marker: {old} is not in {ver}\'s RomFS; the derived profile uses {new}')
        return disp
    up.derive_profile = derive_profile

    import love_shaders
    refuse_capture = up.capture_shaders
    def capture_shaders(repo, d, patched, work, env, logs, g, api):
        """GL capture of a LÖVE game without the Mac host: win/love_shaders.py assembles the GLSL offline from the Lua LÖVE embeds in main (the same text the game hands to glShaderSource)"""
        if api != 'gl': return refuse_capture(repo, d, patched, work, env, logs, g, api)
        out, part = d / 'gl_capture', d / 'gl_capture.partial'
        up.PROG.stage('GL shader reconstruction (LÖVE)')
        up.rmtree(part)
        try: table = g.table(up.CAPTURES['gl']['table'])
        except Exception: table = None
        r = love_shaders.generate(d / 'ExeFS/main', d / 'RomFS', part, table, log=up.say)
        if r is None: return refuse_capture(repo, d, patched, work, env, logs, g, api)
        up.rmtree(out); part.rename(out)
        up.PROG.end(f'{len(r[0])} shaders')
        return out
    up.capture_shaders = capture_shaders

    sys.argv[0] = str(REPO / 'scripts/build_ipa_from_nsp.py')
    return up.cli(sys.argv[1:])   # the upstream entry point: argument parsing, error reporting and the exit code


if __name__ == '__main__':
    sys.exit(main())
