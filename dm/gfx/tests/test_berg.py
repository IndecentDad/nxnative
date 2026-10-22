"""BERG framing and NVN shader extraction without copyrighted game assets."""
import io
import os
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import berg


def record(data, kind=69, compress=True):
    stored = zlib.compress(data) if compress else data
    return struct.pack('<5I', 0xabcd00c5, kind, 0, len(data), len(stored)) + stored


class BergTests(unittest.TestCase):
    def test_stored_zlib_and_exact_frame_boundary(self):
        stream = io.BytesIO(record(b'raw', compress=False) + record(b'x' * 4096, kind=28))
        values = list(berg._records(stream, 'test'))
        self.assertEqual([(kind, data) for _, kind, data in values], [(69, b'raw'), (28, b'x' * 4096)])

    def test_zstd_wrapped_record_followed_by_zlib_record(self):
        import zstandard
        wrapped = zstandard.ZstdCompressor().compress(record(b'inside'))
        values = list(berg._records(io.BytesIO(wrapped + record(b'after')), 'test'))
        self.assertEqual([data for _, _, data in values], [b'inside', b'after'])

    def test_zstd_raw_resource_is_not_mistaken_for_record(self):
        import zstandard
        data = b'class resource description'
        wrapped = zstandard.ZstdCompressor().compress(data)
        values = list(berg._records(io.BytesIO(wrapped + record(b'after')), 'test'))
        self.assertEqual([payload for _, _, payload in values], [data, b'after'])

    def test_footer_must_match_and_end_file(self):
        footer = b'massive\0' + bytes(32) + b'ubisoft\0'
        self.assertEqual(len(list(berg._records(io.BytesIO(record(b'ok') + footer), 'test', footer=footer))), 1)
        with self.assertRaisesRegex(ValueError, 'trailer'):
            list(berg._records(io.BytesIO(record(b'ok') + footer + b'extra'), 'test', footer=footer))

    def test_truncated_record_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'truncated'):
            list(berg._records(io.BytesIO(record(b'incomplete')[:-1]), 'test'))

    def test_old_sdk_control_extracts_complete_shader(self):
        os.environ.setdefault('DM_GAME', '010067300059A000')
        import shader_split
        ctl = bytearray(0x838)
        ctl[:4] = shader_split.CTL_MAGIC
        struct.pack_into('<I', ctl, 0x20, len(ctl))
        code = bytearray(0xb0)
        code[:4] = shader_split.GFX_MAGIC
        struct.pack_into('<I', code, 0x30, 5 << 10)
        struct.pack_into('<I', ctl, 0x704, len(code))
        header = b'BERG' + struct.pack('<I', 22) + bytes(48)
        payload = b'resource metadata' + ctl + code
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'shader.sdfdata'
            path.write_bytes(header + record(payload))
            found = []
            shader_split.berg_shaders(str(path), 'synthetic', found)
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0][1:], ('ps', bytes(ctl), bytes(code)))


if __name__ == '__main__':
    unittest.main()
