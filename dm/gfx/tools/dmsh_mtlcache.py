#!/usr/bin/env python3
# Compiled-shader cache keyed by the Metal source (dmsh_build.py): a library is compiled once per (MSL text, compile convention, compiler), so a chain change
# that leaves a shader's MSL as it was (a translator fix, a new rule for other shaders) costs that shader no Metal compile. The Metal compiler is deterministic:
# the same MSL with the same flags gives a byte-identical metallib (checked for macOS and iOS), which is what makes reuse safe.
# Layout: <cache>/<target>/<2 hex>/<digest>.metallib, digest = sha256 over FORMAT, the target's compile convention (the record written into json chain_metal),
# the compiler's identity (metal / metallib --version without the install path, the SDK version and build) and the MSL bytes.
# Filling from earlier builds: every imported library must record the current compiler identity and flags in its reflection. Legacy libraries without that identity are not imported.
# A fresh compile of two shaders per stage also checks their bytes. Each folder is read once per compiler identity (filled.json remembers its number of libraries).
# Not part of the chain version (dmsh_chain.py): the cache never changes an output, it only skips recompiling one. Change FORMAT when what it stores changes.
import os, re, json, shutil, ctypes, hashlib, threading, subprocess, collections
import windows_metal_exchange as windows_metal

FORMAT = b'dmsh_mtlcache 2'   # earlier prefill could misclassify an unsampled library from another compiler
_clonefile = getattr(ctypes.CDLL(None, use_errno=True), 'clonefile', None)   # APFS copy-on-write copy (no data written); elsewhere a plain copy


def clone(src, dst):
    tmp = f'{dst}.tmp-{os.getpid()}-{threading.get_ident()}'
    if _clonefile is None or _clonefile(os.fsencode(src), os.fsencode(tmp), 0) != 0: shutil.copyfile(src, tmp)
    os.replace(tmp, dst)


def compiler_id(sdk):
    def run(*a): return subprocess.run(['xcrun', '-sdk', sdk, *a], capture_output=True, text=True).stdout
    tools = ''.join(run(t, '--version') for t in ('metal', 'metallib'))
    return re.sub(r'(?m)^InstalledDir:.*\n?', '', tools) + run('--show-sdk-version') + run('--show-sdk-build-version')   # the install path changes with each toolchain mount


class Cache:
    def __init__(self, root, targets, work):
        """targets: {name: (sdk, record, compile)}, compile(msl, air, lib) as ios_metal.compile; work: a folder for temporary .air files"""
        self.root, self.targets, self.work = root, targets, work
        self.ident = {t: hashlib.sha256(FORMAT + b'\0' + rec.encode() + b'\0' + compiler_id(sdk).encode()).digest() for t, (sdk, rec, _) in targets.items()}
        self.stats, self.lock = collections.Counter(), threading.Lock()
        self.windows_cache = os.environ.get("DMSH_WINDOWS_IOS_CACHE")
        self.export_only = bool(os.environ.get("DMSH_WINDOWS_EXPORT_DIR"))
        self.windows_only = os.environ.get("DMSH_WINDOWS_IOS_ONLY") == "1"
        self.provenance_outputs = {}

    def path(self, target, src):
        d = hashlib.sha256(self.ident[target] + b'\0' + src).hexdigest()
        return os.path.join(self.root, target, d[:2], d + '.metallib')

    def with_compiler(self, target, refl):
        return dict(refl, chain_metal=self.targets[target][1], chain_compiler=self.ident[target].hex())

    def count(self, what, n=1):
        with self.lock: self.stats[what] += n

    def _compile(self, target, msl, lib):
        air = os.path.join(self.work, f'mtlcache-{target}-{os.getpid()}-{threading.get_ident()}.air')
        try: self.targets[target][2](msl, air, lib)
        finally:
            if os.path.exists(air): os.unlink(air)

    def compile(self, target, msl, lib):
        """Keep iOS export Windows-only; import only receipt-validated Windows libraries."""
        src = open(msl, 'rb').read()
        key = os.path.basename(lib).removesuffix('.metallib').split('.tmp-', 1)[0]
        if self.export_only:
            if target == 'mac':
                os.makedirs(os.path.dirname(lib), exist_ok=True)
                shutil.copyfile(msl, os.path.splitext(lib)[0] + '.metal')
            self.count((target, 'Windows pending')); return False
        if target == 'ios' and self.windows_only:
            if self.windows_cache:
                flags, _ = windows_metal.ios_flags()
                hit = windows_metal.load_cached(self.windows_cache, src, flags, key)
                if hit:
                    winlib, receipt = hit; clone(winlib, lib); self.count(('ios', 'windows'))
                    self.provenance_outputs[os.path.realpath(lib)] = receipt; return True
            raise subprocess.CalledProcessError(1, ['Windows Metal cache'], stderr=f'no verified Windows metallib for {key}')
        p = self.path(target, src)
        if os.path.exists(p):
            clone(p, lib); self.count((target, 'reused')); self.provenance_outputs[os.path.realpath(lib)] = 'local'; return True
        if target == 'ios' and self.windows_cache:
            flags, _ = windows_metal.ios_flags()
            hit = windows_metal.load_cached(self.windows_cache, src, flags, key)
            if hit:
                winlib, receipt = hit; clone(winlib, lib); self.count(('ios', 'windows'))
                self.provenance_outputs[os.path.realpath(lib)] = receipt; return True
        tmp = f'{lib}.tmp-{os.getpid()}-{threading.get_ident()}'
        self._compile(target, msl, tmp)
        os.replace(tmp, lib)
        os.makedirs(os.path.dirname(p), exist_ok=True); clone(lib, p); self.count((target, 'compiled'))
        self.provenance_outputs[os.path.realpath(lib)] = 'local'; return True

    def _windows_receipt(self, target, msl, shader_key):
        if target != 'ios' or not self.windows_cache: return None
        flags, _ = windows_metal.ios_flags()
        hit = windows_metal.load_cached(self.windows_cache, open(msl, 'rb').read(), flags, shader_key)
        return hit[1] if hit else None

    def provenance(self, target, msl, lib=None, shader_key=None):
        # Keep the actual compiler origin; a Windows library is never labelled as a Tahoe build.
        if target == 'ios':
            v = self.provenance_outputs.get(os.path.realpath(lib)) if lib else None
            if not isinstance(v, dict): v = self._windows_receipt(target, msl, shader_key)
            if isinstance(v, dict): return {k: v.get(k) for k in ('compiler', 'compiler_version', 'air_target', 'source_sha256', 'metallib_sha256')}
        sdk = self.targets[target][0]
        ident = hashlib.sha256(compiler_id(sdk).encode()).hexdigest()[:16]
        return {'compiler': 'local macOS Metal toolchain', 'compiler_fingerprint': ident, 'record': self.targets[target][1]}

    def validate_reflection(self, target, msl, lib, shader_key, metadata_path):
        receipt = self._windows_receipt(target, msl, shader_key)
        if not receipt: return
        try: rows = json.loads(receipt.get('reflection_metadata_json', '{}'))
        except (TypeError, ValueError): rows = {}
        row = rows.get(shader_key)
        if not row or hashlib.sha256(open(metadata_path, 'rb').read()).hexdigest() != row.get('sha256'):
            raise ValueError(f'Windows Metal receipt reflection hash mismatch for {shader_key}')

    def _check(self, target, d, stems, mac_dir):
        """None if folder d was built with the current convention and compiler, else why not"""
        rec, picks = self.targets[target][1], collections.defaultdict(list)
        for stem in stems:
            try: j = json.load(open(os.path.join(d, stem + '.json')))
            except (OSError, ValueError): return f'no readable {stem}.json'
            if j.get('chain_metal') != rec: return f'built with "{j.get("chain_metal")}"'
            if j.get('chain_compiler') != self.ident[target].hex(): return f'{stem} has a different or unrecorded Metal compiler'
            if len(picks[j.get('stage')]) < 2: picks[j.get('stage')].append(stem)
        for stem in (s for v in picks.values() for s in v):
            tmp = os.path.join(self.work, f'mtlcache-check-{target}.metallib')
            try: self._compile(target, os.path.join(mac_dir, stem + '.metal'), tmp)
            except subprocess.CalledProcessError: return f'{stem}.metal does not compile now'
            same = open(tmp, 'rb').read() == open(os.path.join(d, stem + '.metallib'), 'rb').read(); os.unlink(tmp)
            if not same: return f'a fresh compile of {stem}.metal differs from its library'
        return None

    def fill(self, mac_dir, ios_dir=None, targets=None):
        """Takes the libraries of an earlier build: mac_dir = its Mac b-<chain>/ folder, ios_dir = the iOS folder of the same chain (or None). Returns the lines to print"""
        if self.export_only or self.windows_only:
            return []
        stamp_file = os.path.join(self.root, 'filled.json')
        try: stamps = json.load(open(stamp_file))
        except (OSError, ValueError): stamps = {}
        names = set(os.listdir(mac_dir)); stems = sorted(n[:-6] for n in names if n.endswith('_b.metal'))
        todo, notes = {}, []
        for target, d in (('mac', mac_dir), ('ios', ios_dir)):
            if targets is not None and target not in targets: continue   # checking an earlier build compiles samples too
            if target not in self.targets or not d or not os.path.isdir(d): continue
            libs = names if d == mac_dir else set(os.listdir(d))
            have = [s for s in stems if s + '.metallib' in libs]; key = self.ident[target].hex() + ':' + os.path.realpath(d)
            if not have or stamps.get(key) == len(have): continue
            why = self._check(target, d, have, mac_dir)
            if why: notes.append(f'Metal cache: not filled from {d}: {why}')
            else: todo[target] = (d, set(have))
            stamps[key] = len(have)
        added = collections.Counter()
        for stem in stems:
            ts = [t for t, (d, have) in todo.items() if stem in have]
            if not ts: continue
            src = open(os.path.join(mac_dir, stem + '.metal'), 'rb').read()
            for t in ts:
                p = self.path(t, src)
                if os.path.exists(p): continue
                os.makedirs(os.path.dirname(p), exist_ok=True); clone(os.path.join(todo[t][0], stem + '.metallib'), p); added[t] += 1
        for t, (d, have) in todo.items():
            self.count((t, 'filled'), added[t]); notes.append(f'Metal cache: {added[t]} {t} libraries added from {d} ({len(have)} there)')
        os.makedirs(self.root, exist_ok=True)
        tmp = f'{stamp_file}.tmp-{os.getpid()}'; json.dump(stamps, open(tmp, 'w'), indent=1); os.replace(tmp, stamp_file)
        return notes

    def summary(self):
        s = self.stats
        return 'Metal cache: ' + '; '.join(f'{t} {s[t, "reused"]} reused, {s[t, "compiled"]} compiled' + (f', {s[t, "windows"]} Windows' if t == 'ios' and s[t, 'windows'] else '') + (f', {s[t, "filled"]} filled from earlier builds' if s[t, 'filled'] else '')
                                          for t in self.targets)
