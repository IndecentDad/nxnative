#!/usr/bin/env python3
"""Windows split-data tests for the current folder/image RomFS packaging contract."""
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'win'))
sys.path.insert(0, str(REPO / 'dm/tools'))
import romfs as rfs
import build_app


class RomFSSplitData(unittest.TestCase):
    def test_split_data_copies_romfs_folder_and_image_in_documents_layout(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            folder_extract = root / 'folder-extract'
            folder = folder_extract / 'RomFS'
            folder.mkdir(parents=True)
            (folder / 'marker').write_bytes(b'game')
            image_extract = root / 'image-extract'
            image_extract.mkdir()
            image = image_extract / 'RomFS.img'
            image.write_bytes(rfs.MAGIC + bytes(24))

            self.assertFalse(rfs.is_image(folder))
            self.assertEqual(rfs.source(folder_extract), folder)
            self.assertTrue(rfs.is_image(image))
            self.assertEqual(rfs.source(image_extract), image)

            folder_data = root / 'folder-data'
            files, size = build_app.split_data(folder_data, {'romfs': folder}, 'game\tceleste\n', 'Celeste')
            self.assertEqual((files, size), (1, 4))
            self.assertEqual((folder_data / 'romfs' / 'marker').read_bytes(), b'game')

            image_data = root / 'image-data'
            files, size = build_app.split_data(image_data, {'romfs.img': image}, 'game\tceleste\n', 'Celeste')
            self.assertEqual((files, size), (1, image.stat().st_size))
            self.assertEqual((image_data / 'romfs.img').read_bytes(), image.read_bytes())


if __name__ == '__main__':
    unittest.main(verbosity=2)
