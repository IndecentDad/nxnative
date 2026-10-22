import importlib.util
import plistlib
import tempfile
import unittest
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / 'tools/configure_icloud.py'
spec = importlib.util.spec_from_file_location('configure_icloud', SOURCE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ConfigureCloudTests(unittest.TestCase):
    def test_two_games_share_capability_but_keep_identity(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for title in ('010093801237C000', '010015100B514000'):
                info, ent = root / f'{title}.plist', root / f'{title}.entitlements'
                with info.open('wb') as file:
                    plistlib.dump({'CFBundleIdentifier': f'org.nxnative.{title.lower()}'}, file)
                result, signing = module.configure(info, ent, title, 'iCloud.org.nxnative.saves', 'ABCDE12345')
                self.assertEqual(result['DMTitleID'], title)
                self.assertEqual(result['CFBundleIdentifier'], f'org.nxnative.{title.lower()}')
                self.assertTrue(result['NSUbiquitousContainers']['iCloud.org.nxnative.saves']['NSUbiquitousContainerIsDocumentScopePublic'])
                self.assertIn('CloudDocuments', signing['com.apple.developer.icloud-services'])
                with ent.open('rb') as file:
                    self.assertEqual(plistlib.load(file), signing)

    def test_without_icloud_retains_existing_entitlements(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            info, ent, base = root / 'Info.plist', root / 'out.plist', root / 'base.plist'
            for path, data in ((info, {}), (base, {'com.apple.developer.kernel.increased-memory-limit': True})):
                with path.open('wb') as file: plistlib.dump(data, file)
            result, signing = module.configure(info, ent, '010093801237C000', base=str(base))
            self.assertNotIn('NSUbiquitousContainers', result)
            self.assertTrue(signing['com.apple.developer.kernel.increased-memory-limit'])

    def test_invalid_cloud_configuration_fails(self):
        with tempfile.TemporaryDirectory() as temporary:
            info = Path(temporary) / 'Info.plist'
            with info.open('wb') as file: plistlib.dump({}, file)
            with self.assertRaises(ValueError):
                module.configure(info, info.parent / 'entitlements', '010093801237C000', 'iCloud.org.nxnative.saves', '0000000000')


if __name__ == '__main__': unittest.main()
