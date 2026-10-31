"""SMB routing tests; uses temporary local files and never extracts a game."""
import hashlib, json, tempfile, unittest, zipfile
from pathlib import Path
from unittest.mock import patch
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import staging


class SmbStagingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.source = root / 'share' / 'Celeste [0100000000000000].nsp'
        self.source.parent.mkdir(); self.source.write_bytes(b'game input bytes')
        self.workspace = root / 'local' / 'NXNative'
        self.repo = root / 'repo'; profile = self.repo / 'dm/games/0100000000000000'; profile.mkdir(parents=True)
        (profile / 'game.tsv').write_text('ipa\tCeleste.ipa\n', encoding='utf-8')

    def tearDown(self): self.tmp.cleanup()

    def network(self, path): return Path(path) == self.source

    def test_packaged_workspace_root_is_the_executable_directory(self):
        exe = Path(r'D:\\NXNativeBuilds\\NXNative.exe')
        self.assertEqual(staging.application_root(executable=exe, frozen=True), exe.parent)
        with patch.object(staging, 'local_workspace_root', return_value=exe.parent):
            work = staging.local_split_data_folder([self.source], r'\\nas\out\Celeste.ipa')
        self.assertEqual(work, exe.parent / '0100000000000000' / 'outputs' / 'Celeste-data')

    def test_split_data_is_zipped_locally_then_transferred_as_one_file(self):
        data = self.workspace / 'Celeste-data'; (data / 'romfs').mkdir(parents=True)
        (data / 'romfs' / 'asset.bin').write_bytes(b'asset')
        (data / 'README.txt').write_text('copy the extracted folder')
        destination = self.workspace / 'share' / 'Celeste-data.zip'
        result = staging.zip_split_data(data, destination)
        self.assertEqual(result, destination)
        self.assertTrue(data.is_dir())
        with zipfile.ZipFile(destination) as archive:
            self.assertEqual(archive.read('Celeste-data/romfs/asset.bin'), b'asset')
            self.assertEqual(archive.getinfo('Celeste-data/romfs/asset.bin').compress_type, zipfile.ZIP_DEFLATED)
            self.assertIn('Celeste-data/README.txt', archive.namelist())
        self.assertTrue((self.workspace / 'Celeste-data.zip').is_file())

    def test_failed_archive_transfer_preserves_old_archive_and_local_data(self):
        data = self.workspace / 'Celeste-data'; data.mkdir(parents=True)
        (data / 'asset').write_bytes(b'local complete data')
        destination = self.workspace / 'share' / 'Celeste-data.zip'; destination.parent.mkdir()
        destination.write_bytes(b'previous completed archive')
        def fail_transfer(_src, dst):
            Path(dst).write_bytes(b'incomplete')
            raise OSError('simulated network write failure')
        with patch.object(staging.shutil, 'copyfile', side_effect=fail_transfer):
            with self.assertRaisesRegex(OSError, 'simulated network write failure'):
                staging.zip_split_data(data, destination)
        self.assertEqual(destination.read_bytes(), b'previous completed archive')
        self.assertEqual((data / 'asset').read_bytes(), b'local complete data')
        self.assertTrue((self.workspace / 'Celeste-data.zip').is_file())
        self.assertFalse(destination.with_name(destination.name + '.partial').exists())

    def test_application_root_in_script_mode_uses_local_per_user_fallback(self):
        with patch.dict(staging.os.environ, {'LOCALAPPDATA': str(self.workspace)}):
            self.assertEqual(staging.application_root(frozen=False), self.workspace / 'NXNative' / 'SMB')

    def test_unc_path_is_classified_as_network(self):
        self.assertTrue(staging.is_network_path(r'\\nas\games\Celeste.nsp'))

    def test_network_inputs_copy_to_local_workspace_and_default_outputs_stay_by_source(self):
        folder, copied = staging.stage_folder([self.source], self.workspace, self.network)
        self.assertEqual(folder, self.workspace / '0100000000000000' / 'inputs')
        self.assertEqual(copied, [self.source.name])
        self.assertEqual((folder / self.source.name).read_bytes(), self.source.read_bytes())
        self.assertEqual(staging.default_network_output([self.source], self.repo), self.source.parent / 'Celeste.ipa')
        self.assertEqual(self.source.read_bytes(), b'game input bytes')

    def test_verified_local_copy_is_reused_then_refreshed_when_source_changes(self):
        folder, _ = staging.stage_folder([self.source], self.workspace, self.network)
        copied_file = folder / self.source.name
        first_hash = hashlib.sha256(copied_file.read_bytes()).hexdigest()
        with patch.object(staging.shutil, 'copy2', side_effect=AssertionError('should reuse a verified copy')):
            again, copied = staging.stage_folder([self.source], self.workspace, self.network)
        self.assertEqual(again, folder); self.assertEqual(copied, [])
        self.assertEqual(json.loads((folder / '.nxw-inputs.json').read_text())['files'][self.source.name]['sha256'], first_hash)
        self.source.write_bytes(b'updated input')
        folder, copied = staging.stage_folder([self.source], self.workspace, self.network)
        self.assertEqual(copied, [self.source.name]); self.assertEqual((folder / self.source.name).read_bytes(), b'updated input')

    def test_local_same_volume_staging_prefers_hard_links(self):
        second = self.source.parent / 'Other [0100000000000000].nsp'; second.write_bytes(b'other')
        folder, _ = staging.stage_folder([self.source], self.workspace, lambda _p: False)
        self.assertEqual(folder, self.source.parent / '0100000000000000_nxw')
        self.assertTrue(self.source.samefile(folder / self.source.name))

    def test_copy_failure_preserves_existing_build_cache_and_staged_input(self):
        folder, _ = staging.stage_folder([self.source], self.workspace, self.network)
        staged = folder / self.source.name
        cache_artifact = folder / '0100000000000000_build' / 'extract' / 'complete.marker'
        cache_artifact.parent.mkdir(parents=True); cache_artifact.write_bytes(b'completed artifact')
        other = self.source.parent / 'Update [0100000000000800].nsp'; other.write_bytes(b'new update')
        original_copy = staging.shutil.copy2
        def fail_second(src, dst, *args, **kwargs):
            if Path(src) == other: raise OSError('simulated SMB read failure')
            return original_copy(src, dst, *args, **kwargs)
        with patch.object(staging.shutil, 'copy2', side_effect=fail_second):
            with self.assertRaisesRegex(OSError, 'simulated SMB read failure'):
                staging.stage_folder([self.source, other], self.workspace, self.network)
        self.assertEqual(staged.read_bytes(), b'game input bytes')
        self.assertEqual(cache_artifact.read_bytes(), b'completed artifact')
        self.assertFalse((folder / (other.name + '.nxw-partial')).exists())


if __name__ == '__main__': unittest.main(verbosity=2)
