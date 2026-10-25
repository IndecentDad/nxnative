# Loaded by every Python the Windows driver starts (win/build_ipa_windows.py puts win/pyshim first on PYTHONPATH), including the child Pythons the pipeline spawns
# (patch_nso.py workers, dmsh_build.py through own_compilers.py, settings.py, ...). It leaves the upstream sources untouched and rewrites, at the subprocess boundary only,
# the commands that name macOS tools:
#   xcrun ...                          → python win/xcrun.py ...            (Metal Developer Tools for Windows, LLVM)
#   .../dmsh_xlate_bin/dmsh_xlate ...  → dotnet .../dmsh_xlate.dll ...      (the committed apphost is a Mach-O; the DLLs are the locked translator build)
#   which <tool>                       → shutil.which                       (dmsh_chain.py fingerprints spirv-cross through `which`)
#   bash .../dm/ios/tools/build_ipa.sh → python win/build_app.py            (the Xcode build, replaced by the LLVM build)
#   python3 ...                        → this Python
# It also makes ctypes.CDLL(None) (macOS's "the process itself", used to look up clonefile) return an empty library instead of raising, so the
# modules that probe for APFS clones import and fall back to plain copies.
import os, sys
if os.name == 'nt' and not os.environ.get('NXW_SHIM_OFF'):
    import ctypes, shutil, subprocess
    from pathlib import Path
    _WIN = Path(__file__).resolve().parent.parent
    _XCRUN = str(_WIN / 'xcrun.py')
    _BUILD_APP = str(_WIN / 'build_app.py')

    class _NoLib:
        def __getattr__(self, name): raise AttributeError(f'{name} (no process-wide C library on Windows)')
    _CDLL = ctypes.CDLL
    def _cdll(name, *a, **k):
        return _NoLib() if name is None else _CDLL(name, *a, **k)
    ctypes.CDLL = _cdll

    def _map(args):
        if isinstance(args, (str, bytes)) or not args: return args
        args = [os.fspath(a) if isinstance(a, os.PathLike) else a for a in args]
        if not isinstance(args[0], str): return args
        head = args[0].replace('\\', '/'); base = head.rsplit('/', 1)[-1].lower()
        if base in ('xcrun', 'xcrun.exe'): return [sys.executable, _XCRUN] + args[1:]
        if base == 'dmsh_xlate' and '/dmsh_xlate_bin/' in head: return [shutil.which('dotnet') or 'dotnet', args[0] + '.dll'] + args[1:]
        if base in ('python3', 'python3.exe'): return [sys.executable] + args[1:]
        if base in ('bash', 'bash.exe') and len(args) > 1 and args[1].replace('\\', '/').endswith('dm/ios/tools/build_ipa.sh'): return [sys.executable, _BUILD_APP] + args[2:]
        if base == 'which' and len(args) == 2: return [sys.executable, '-c', 'import shutil,sys; p=shutil.which(sys.argv[1]); print(p or ""); sys.exit(0 if p else 1)', args[1]]
        return args

    # NXW_AUTO_SDK_CUTS (a JSON file the Windows driver writes, win/sdk_auto_cuts.py): {sdk build ID: [[offset, old, new, reason], ...]} for sdk builds dm/tools/sdk_patches.py does not
    # register. patch_nso.py loads sdk_patches.py by its path (importlib.util.spec_from_file_location); its CUTS gain these entries, never replacing a registered build's
    if os.environ.get('NXW_AUTO_SDK_CUTS'):
        import importlib.util, json
        _sffl = importlib.util.spec_from_file_location
        def _spec_from_file_location(name, location=None, *a, **k):
            spec = _sffl(name, location, *a, **k)
            if spec and location and os.fspath(location).replace('\\', '/').endswith('dm/tools/sdk_patches.py'):
                load = spec.loader.exec_module
                def exec_module(m):
                    load(m)
                    try: extra = json.loads(Path(os.environ['NXW_AUTO_SDK_CUTS']).read_text(encoding='utf-8'))
                    except (OSError, ValueError): return
                    for bid, cuts in extra.items(): m.CUTS.setdefault(bid, [tuple(c) for c in cuts])
                spec.loader.exec_module = exec_module
            return spec
        importlib.util.spec_from_file_location = _spec_from_file_location

    _init = subprocess.Popen.__init__
    def _popen_init(self, args, *a, **k):
        if os.environ.get('NXW_SHIM_TRACE'): print('nxw shim:', args, '->', _map(args), file=sys.stderr)
        _init(self, _map(args), *a, **k)
    subprocess.Popen.__init__ = _popen_init
