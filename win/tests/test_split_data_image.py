import importlib.util
from pathlib import Path
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('build_app', REPO / 'win/build_app.py')
assert spec and spec.loader
build_app = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build_app)

class SplitImageData(unittest.TestCase):
    def test_split_data_accepts_romfs_image_as_documents_file(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td); image = root / 'RomFS.img'; image.write_bytes(b'DMROMFS1 test image')
            self.assertEqual(build_app.list_files(image), [(str(image), image.name, image.stat().st_size)])
            data = root / 'game-data'
            files, size = build_app.split_data(data, {'romfs.img': image}, 'game\\t040074A01BF12000\\n', 'Bananza')
            self.assertEqual((files, size), (1, image.stat().st_size))
            self.assertEqual((data / 'romfs.img').read_bytes(), image.read_bytes())

if __name__ == '__main__': unittest.main()
