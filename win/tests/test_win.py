#!/usr/bin/env python3
# Unit tests of the Windows port's pure-Python parts (no SDK, Metal tools or game files needed): python win/tests/test_win.py
import io, lzma, os, plistlib, struct, subprocess, sys, tempfile, unittest, zlib, zipfile
from pathlib import Path
WIN = Path(__file__).resolve().parents[1]
REPO = WIN.parent
sys.path.insert(0, str(WIN)); sys.path.insert(0, str(WIN / 'sdk'))
import xcrun, build_app, extract_xip


class Xcrun(unittest.TestCase):
    def test_ios_min_becomes_target(self):
        a = xcrun.metal_args('iphoneos', ['-c', '-mios-version-min=18.0', '-fmetal-math-mode=relaxed', 'x.metal', '-o', 'x.air'])
        i = a.index('-target'); self.assertEqual(a[i + 1], 'air64-apple-ios18.0')
        self.assertNotIn('-mios-version-min=18.0', a)

    def test_macos_gets_default_target(self):
        a = xcrun.metal_args('macosx', ['-c', '-fpreserve-invariance', 'x.metal', '-o', 'x.air'])
        self.assertEqual(a[0], '-target'); self.assertTrue(a[1].startswith('air64-apple-macos'))

    def test_version_query_untouched(self):
        self.assertEqual(xcrun.metal_args('iphoneos', ['--version']), ['--version'])


class Shim(unittest.TestCase):
    def run_mapped(self, code):
        env = dict(os.environ, PYTHONPATH=str(WIN / 'pyshim'), NXW_SHIM_TRACE='1')
        return subprocess.run([sys.executable, '-c', code], capture_output=True, text=True, env=env)

    @unittest.skipUnless(os.name == 'nt', 'the shim is active on Windows only')
    def test_which_python3_and_cdll(self):
        r = self.run_mapped('import subprocess, ctypes, sys\n'
                            'p = subprocess.run(["which", "python"], capture_output=True, text=True); print("which", p.returncode, bool(p.stdout.strip()))\n'
                            'p = subprocess.run(["python3", "-c", "print(42)"], capture_output=True, text=True); print("py3", p.stdout.strip())\n'
                            'print("clone", getattr(ctypes.CDLL(None), "clonefile", None))')
        self.assertIn('which 0 True', r.stdout, r.stderr); self.assertIn('py3 42', r.stdout); self.assertIn('clone None', r.stdout)

    @unittest.skipUnless(os.name == 'nt', 'the shim is active on Windows only')
    def test_xlate_and_build_ipa_mapping(self):
        r = self.run_mapped('import sitecustomize, subprocess\n'
                            'try: subprocess.run(["C:/r/dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate", "--source-sha"])\nexcept OSError: pass\n'
                            'try: subprocess.run(["bash", "C:/r/dm/ios/tools/build_ipa.sh", "out.ipa"], capture_output=True)\nexcept OSError: pass\n')
        self.assertIn("dmsh_xlate.dll', '--source-sha']", r.stderr)
        self.assertIn("build_app.py', 'out.ipa']", r.stderr)


class HostSources(unittest.TestCase):
    def test_matches_makefile(self):
        files, incs = build_app.host_sources(Path('gen/x'))
        names = {f.name for f in files}
        self.assertIn('main.c', names); self.assertIn('entry.S', names); self.assertNotIn('front_mac.m', names)
        self.assertTrue(any(f.parent.name == 'nvn' for f in files)); self.assertTrue(any('libvpx' in str(f) for f in files))
        self.assertTrue(all(f.exists() for f in files))
        self.assertEqual(incs[0], (REPO / 'dm/gfx/nvn/include').resolve())


class Plist(unittest.TestCase):
    def test_keys(self):
        p = build_app.info_plist('org.nxnative.x', 'Game', '1.2.1', 'public.app-category.games', False, 'en-US', '26.0', '23A1', True)
        self.assertEqual(p['CFBundleExecutable'], 'DmIOS'); self.assertEqual(p['MinimumOSVersion'], '26.0')
        self.assertEqual(p['UIApplicationSceneManifest']['UISceneConfigurations']['UIWindowSceneSessionRoleApplication'][0]['UISceneDelegateClassName'], 'SceneDelegate')
        plistlib.dumps(p, fmt=plistlib.FMT_BINARY)


def odc(name, mode, data=b'', ino=1):
    n = name.encode() + b'\0'
    h = b'070707' + b'%06o' % 0 + b'%06o' % ino + b'%06o' % mode + b'%06o' % 0 * 2 + b'%06o' % 1 + b'%06o' % 0 + b'%011o' % 0 + b'%06o' % len(n) + b'%011o' % len(data)
    return h + n + data


class Xip(unittest.TestCase):
    def test_extracts_only_the_sdk(self):
        sdk = './Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/'
        cpio = (odc('./Xcode.app/Contents/Info.plist', 0o100644, b'skip me') + odc(sdk + 'iPhoneOS.sdk', 0o040755) +
                odc(sdk + 'iPhoneOS.sdk/SDKSettings.json', 0o100644, b'{"Version": "26.0"}', ino=7) +
                odc(sdk + 'iPhoneOS.sdk/usr/lib/libz.tbd', 0o120755, b'libz.1.tbd') + odc(sdk + 'iPhoneOS.sdk/usr/lib/libz.1.tbd', 0o100644, b'tbd', ino=8) +
                odc(sdk + 'iPhoneOS26.0.sdk', 0o120755, b'iPhoneOS.sdk') + odc('TRAILER!!!', 0))
        half = len(cpio) // 2
        body = b'pbzx' + struct.pack('>Q', 1 << 24)
        for part in (cpio[:half], cpio[half:]):
            c = lzma.compress(part, format=lzma.FORMAT_XZ); body += struct.pack('>QQ', 1 << 24, len(c)) + c
        toc = (f'<?xml version="1.0"?><xar><toc><file id="1"><name>Content</name><data><offset>0</offset><length>{len(body)}</length>'
               '<encoding style="application/octet-stream"/></data></file></toc></xar>').encode()
        tc = zlib.compress(toc)
        xip = b'xar!' + struct.pack('>HHQQI', 28, 1, len(tc), len(toc), 0) + tc + body
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'x.xip'; p.write_bytes(xip); out = Path(d) / 'out'
            sys.argv = ['extract_xip.py', str(p), str(out)]
            extract_xip.main()
            self.assertEqual((out / 'iPhoneOS.sdk/SDKSettings.json').read_bytes(), b'{"Version": "26.0"}')
            self.assertEqual((out / 'iPhoneOS.sdk/usr/lib/libz.tbd').read_bytes(), b'tbd')
            self.assertFalse((out / 'Info.plist').exists()); self.assertFalse((out / 'iPhoneOS26.0.sdk').exists())


class PackIpa(unittest.TestCase):
    def test_exec_bit_on_windows(self):
        with tempfile.TemporaryDirectory() as d:
            app = Path(d) / 'DmIOS.app'; app.mkdir(); (app / 'DmIOS').write_bytes(b'\xcf\xfa\xed\xfe'); (app / 'Info.plist').write_bytes(b'x')
            ipa = Path(d) / 'a.ipa'
            subprocess.run([sys.executable, str(REPO / 'dm/ios/tools/pack_ipa.py'), str(ipa), '--exec', 'Payload/DmIOS.app/DmIOS', f'Payload/DmIOS.app={app}'], check=True, capture_output=True)
            with zipfile.ZipFile(ipa) as z: modes = {i.filename: i.external_attr >> 16 for i in z.infolist()}
            self.assertEqual(modes['Payload/DmIOS.app/DmIOS'] & 0o777, 0o755)
            self.assertEqual(modes['Payload/DmIOS.app/Info.plist'] & 0o777, 0o644 if os.name == 'nt' else modes['Payload/DmIOS.app/Info.plist'] & 0o777)


if __name__ == '__main__':
    unittest.main(verbosity=2)
