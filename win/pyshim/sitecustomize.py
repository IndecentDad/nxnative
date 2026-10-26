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

    # Text files written as on a Mac: Python on Windows turns '\n' into '\r\n' in text mode, and the host compares lines of the pipeline's tables as they are
    # (an iPad run refused a shader library because inputs.tsv's "game\t<id>\r" did not match, and took c1_full.tsv as stale). Every text-mode open that names no newline writes '\n'.
    import builtins, io
    _open = io.open
    def _lf_open(file, mode='r', buffering=-1, encoding=None, errors=None, newline=None, closefd=True, opener=None):
        if newline is None and 'b' not in mode and any(c in mode for c in 'wax+'): newline = '\n'
        return _open(file, mode, buffering, encoding, errors, newline, closefd, opener)
    io.open = builtins.open = _lf_open

    # os.replace as on a Mac: Windows refuses to replace a file another thread has open, which POSIX rename allows. The shader build's content-addressed caches
    # (dmsh_mtlcache.py) have threads finish the same entry at once; a replace that keeps failing onto an existing file of the same size is that race, and the copy goes
    import time as _time
    _replace = os.replace
    def _win_replace(src, dst, *a, **k):
        for i in range(20):
            try: return _replace(src, dst, *a, **k)
            except PermissionError:
                if i == 19:
                    try:
                        if os.path.isfile(dst) and os.path.getsize(dst) == os.path.getsize(src): os.remove(src); return None
                    except OSError: pass
                    raise
                _time.sleep(0.05 * (i + 1))
    os.replace = _win_replace

    class _NoLib:
        def __getattr__(self, name): raise AttributeError(f'{name} (no process-wide C library on Windows)')
    class _CCCrypt:
        """CommonCrypto's CCCrypt (uepak.py decrypts Unreal pak indexes with AES-256 ECB through it) on Windows' CNG (bcrypt.dll): AES in ECB mode, decrypt and encrypt, no padding"""
        restype = argtypes = None
        def __call__(self, op, alg, options, key, keylen, iv, data, datalen, out, outlen, moved):
            if alg != 0 or options not in (0, 2): return -4301   # kCCUnimplemented: only AES (0) in ECB mode (2), unpadded
            from ctypes import wintypes, byref, c_void_p, c_ulong, create_unicode_buffer
            bc = ctypes.WinDLL('bcrypt'); h = c_void_p(); hk = c_void_p(); res = c_ulong()
            if bc.BCryptOpenAlgorithmProvider(byref(h), ctypes.c_wchar_p('AES'), None, 0): return -4300
            try:
                mode = create_unicode_buffer('ChainingModeECB')
                bc.BCryptSetProperty(h, ctypes.c_wchar_p('ChainingMode'), mode, ctypes.sizeof(mode), 0)
                k = bytes(key)[:keylen]
                if bc.BCryptGenerateSymmetricKey(h, byref(hk), None, 0, k, len(k), 0): return -4300
                src = bytes(data)[:datalen]
                fn = bc.BCryptDecrypt if op == 1 else bc.BCryptEncrypt
                if fn(hk, src, len(src), None, None, 0, out, outlen, byref(res), 0): return -4300
                moved._obj.value = res.value if hasattr(moved, '_obj') else res.value
                return 0
            finally:
                if hk: bc.BCryptDestroyKey(hk)
                bc.BCryptCloseAlgorithmProvider(h, 0)
    class _LibSystem:
        CCCrypt = _CCCrypt()
    _CDLL = ctypes.CDLL
    def _cdll(name, *a, **k):
        if name is None: return _NoLib()
        if isinstance(name, str) and name.endswith('libSystem.B.dylib'): return _LibSystem()
        return _CDLL(name, *a, **k)
    ctypes.CDLL = _cdll

    _XC = {}
    def _xcrun_direct(rest):
        """xcrun -sdk <sdk> metal / metallib ... straight to the Windows Metal tool, without a Python per call (a shader build makes thousands of them: about 0.1 s each).
        None for anything else, which goes through win/xcrun.py"""
        if len(rest) < 3 or rest[0] not in ('-sdk', '--sdk') or rest[2] not in ('metal', 'metallib'): return None
        if 'mod' not in _XC:
            sys.path.insert(0, str(_WIN)); import xcrun as _x, toolchain as _t; _XC['mod'] = (_x, _t)
        x, t = _XC['mod']; sdk, tool = rest[1], rest[2]
        key = (sdk, tool)
        if key not in _XC: _XC[key] = t.metal_tool(sdk, tool)
        exe = _XC[key]
        if not exe: return None
        return [str(exe)] + (x.metal_args(sdk, rest[3:]) if tool == 'metal' else rest[3:])

    def _map(args):
        if isinstance(args, (str, bytes)) or not args: return args
        args = [os.fspath(a) if isinstance(a, os.PathLike) else a for a in args]
        if not isinstance(args[0], str): return args
        head = args[0].replace('\\', '/'); base = head.rsplit('/', 1)[-1].lower()
        if base in ('xcrun', 'xcrun.exe'): return _xcrun_direct(args[1:]) or [sys.executable, _XCRUN] + args[1:]
        if base == 'nxw_oodle_host': return [sys.executable, str(_WIN / 'oodle_emu.py')] + args[1:]   # the Mac host's decoder tool mode, emulated
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
