"""Snowdrop BERG v22 records from Mario + Rabbids' .sdfdata files.

The 0x38-byte BERG header precedes 20-byte LE record headers: magic
0xabcd00c5, type, flags, decoded length, stored length. Records are stored
or zlib-compressed; some complete records are wrapped in one zstd frame.
"""
import io
import struct
import zlib

MAGIC = b'\xc5\x00\xcd\xab'
ZSTD = b'\x28\xb5\x2f\xfd'


def _zstd_frame(stream):
    try:
        import zstandard
    except ImportError as error:
        raise ValueError('BERG zstd frames need zstandard in the build Python environment') from error
    decoder = zstandard.ZstdDecompressor().decompressobj()
    parts = []
    while not decoder.eof:
        chunk = stream.read(65536)
        if not chunk:
            raise ValueError('truncated BERG zstd frame')
        parts.append(decoder.decompress(chunk))
    stream.seek(-len(decoder.unused_data), io.SEEK_CUR)
    return b''.join(parts)


def _records(stream, label, depth=0, footer=None):
    if depth > 4:
        raise ValueError(f'{label}: too many nested BERG compression frames')
    while True:
        offset = stream.tell()
        magic = stream.read(4)
        if not magic:
            return
        stream.seek(offset)
        where = f'{label}@{offset:#x}'
        if footer and magic == footer[:4]:
            if stream.read(len(footer)) != footer or stream.read(1):
                raise ValueError(f'{where}: invalid BERG trailer')
            return
        if magic == ZSTD:
            data = _zstd_frame(stream)
            # Frames can hold a raw resource (including text), or exactly one
            # of the zlib record wrappers used by the surrounding stream.
            nested = False
            if len(data) >= 20 and data[:4] == MAGIC:
                _, _, flags, _, stored = struct.unpack_from('<5I', data)
                nested = not flags and stored == len(data) - 20
            if nested:
                yield from _records(io.BytesIO(data), where + ':zstd', depth + 1)
            else:
                yield where + ':zstd', None, data
            continue
        header = stream.read(20)
        if len(header) != 20 or magic != MAGIC:
            raise ValueError(f'{where}: invalid BERG record header ({magic.hex()})')
        _, kind, flags, size, stored = struct.unpack('<5I', header)
        if flags:
            raise ValueError(f'{where}: unsupported BERG flags {flags:#x}')
        data = stream.read(stored)
        if len(data) != stored:
            raise ValueError(f'{where}: truncated BERG record')
        if stored != size:
            data = zlib.decompress(data)
        if len(data) != size:
            raise ValueError(f'{where}: BERG decoded length mismatch ({len(data)} != {size})')
        yield where, kind, data


def records(path, label):
    with open(path, 'rb') as stream:
        header = stream.read(0x38)
        if len(header) != 0x38 or header[:4] != b'BERG' or struct.unpack_from('<I', header, 4)[0] != 22:
            raise ValueError(f'{label}: unsupported BERG header/version')
        yield from _records(stream, label, footer=header[8:])
