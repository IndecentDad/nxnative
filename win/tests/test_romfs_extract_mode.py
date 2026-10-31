#!/usr/bin/env python3
"""Focused NSP extraction-mode tests; no game files, SDK, shader compiler, or build required."""
import importlib.util, sys, tempfile, unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'dm/tools'))
import romfs_image

spec = importlib.util.spec_from_file_location('build_ipa_from_nsp', REPO / 'scripts/build_ipa_from_nsp.py')
upstream = importlib.util.module_from_spec(spec)
spec.loader.exec_module(upstream)


class RomFSExtractionMode(unittest.TestCase):
    def extraction(self, root, image):
        root.mkdir(parents=True)
        (root / 'ExeFS').mkdir()
        (root / 'ExeFS/main').write_bytes(b'main')
        files = root / 'source'; files.mkdir()
        (files / 'marker').write_bytes(b'game')
        if image:
            romfs_image.pack(files, root / 'RomFS.img')
        else:
            import shutil
            shutil.copytree(files, root / 'RomFS')
        return root

    def test_normal_and_split_select_expected_extractor_arguments(self):
        self.assertTrue(upstream.romfs_image_mode({}))
        self.assertTrue(upstream.romfs_image_mode({'NXW_SPLIT_DATA': '0'}))
        self.assertFalse(upstream.romfs_image_mode({'NXW_SPLIT_DATA': '1'}))
        self.assertFalse(upstream.romfs_image_mode({'NXW_SPLIT_DATA': r'D:\Games\Title-data'}))
        base = ['nx_extract', 'keys', 'base.nsp', '-', 'out']
        self.assertEqual(upstream.extraction_command(*base, True, False), base + ['--romfs-image'])
        self.assertEqual(upstream.extraction_command(*base, False, False), base)

    def test_reuse_requires_the_requested_format(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            image = self.extraction(root / 'image', True)
            folder = self.extraction(root / 'folder', False)
            self.assertTrue(upstream.extraction_reusable(image, 'marker', True))
            self.assertFalse(upstream.extraction_reusable(image, 'marker', False))
            self.assertTrue(upstream.extraction_reusable(folder, 'marker', False))
            self.assertFalse(upstream.extraction_reusable(folder, 'marker', True))

    def test_image_to_folder_switch_preserves_sibling_artifacts(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); dst = self.extraction(root / 'extract/v0', True)
            (dst / 'glslc_capture').mkdir()
            (dst / 'glslc_capture/output.glsl').write_bytes(b'captured shader')
            staged = self.extraction(root / 'extract/v0.partial', False)
            upstream.install_extraction(staged, dst, 'marker', False)
            self.assertTrue(upstream.extraction_reusable(dst, 'marker', False))
            self.assertFalse((dst / 'RomFS.img').exists())
            self.assertEqual((dst / 'glslc_capture/output.glsl').read_bytes(), b'captured shader')
            self.assertEqual((dst / 'ExeFS/main').read_bytes(), b'main')

    def test_folder_to_image_switch_preserves_sibling_artifacts(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); dst = self.extraction(root / 'extract/v0', False)
            (dst / 'shader-cache').mkdir()
            (dst / 'shader-cache/output.metallib').write_bytes(b'cached shader')
            staged = self.extraction(root / 'extract/v0.partial', True)
            upstream.install_extraction(staged, dst, 'marker', True)
            self.assertTrue(upstream.extraction_reusable(dst, 'marker', True))
            self.assertFalse((dst / 'RomFS').exists())
            self.assertEqual((dst / 'shader-cache/output.metallib').read_bytes(), b'cached shader')
            self.assertEqual((dst / 'ExeFS/main').read_bytes(), b'main')


if __name__ == '__main__':
    unittest.main(verbosity=2)
