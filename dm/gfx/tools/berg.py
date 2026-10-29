"""Snowdrop BERG v22 records from Mario + Rabbids' .sdfdata files.

The 0x38-byte BERG header precedes 20-byte LE record headers: magic
0xabcd00c5, type, flags, decoded length, stored length. Records are stored
or zlib-compressed; some complete records are wrapped in one zstd frame.
"""
import io
import os
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


def index(path):
    """WEST v22 prefix tree; layout cross-checked with rouge_sdf/main.cpp.
    Rabbids has 204-byte DDS header entries and no v23 per-chunk file ID.
    Archive offsets, not content signatures, delimit unframed resources.
    """
    with open(path, 'rb') as stream:
        data = stream.read()
    magic, version, size, stored, _, archives, dds = struct.unpack_from('<7I', data)
    if magic != 0x54534557 or version != 22:
        raise ValueError(f'{path}: unsupported WEST version {version}')
    start = 77 + (320 if data[76] else 0) + archives * 52 + dds * 204
    blob = data[start:start + stored]
    if len(blob) != stored: raise ValueError(f'{path}: truncated WEST table')
    table = _zstd_frame(io.BytesIO(blob)) if blob[:4] == ZSTD else zlib.decompress(blob)
    if len(table) != size: raise ValueError(f'{path}: WEST table length mismatch')
    stack, seen, entries = [(0, b'')], set(), []
    while stack:
        pos, name = stack.pop()
        if pos in seen: raise ValueError(f'{path}: repeated WEST tree node {pos:#x}')
        seen.add(pos)
        def integer(count):
            nonlocal pos
            if pos + count > len(table): raise ValueError(f'{path}: truncated WEST descriptor at {pos:#x}')
            value = int.from_bytes(table[pos:pos + count], 'little'); pos += count
            return value
        tag = integer(1)
        if 1 <= tag <= 31:
            if pos + tag > len(table): raise ValueError(f'{path}: truncated WEST name')
            stack.append((pos + tag, name + table[pos:pos + tag]))
        elif 65 <= tag <= 90:
            parts = (tag - 65) & 7
            if not parts: continue
            integer(4); integer(integer(1) & 3)  # resource hash; optional DDS header index
            for _ in range(parts):
                descriptor = integer(1)
                if not descriptor: continue  # absent segment in an updated resource
                width = (descriptor & 3) + 1
                decoded = integer(width)
                compressed = bool(descriptor & 32)
                packed = integer(width) if compressed else decoded
                offset = integer((descriptor >> 2) & 7)
                archive = integer(2)
                pages = [integer(2) for _ in range((decoded + 65535) // 65536)] if compressed and decoded > 65536 else [packed] if compressed else []
                # DLCs use sparse global IDs (e.g. 3000), while the header
                # counts only the archives physically present in this set.
                entries.append((name.decode('utf-8'), archive, offset, decoded, packed, pages))
        elif tag:
            target = integer(4)
            stack.extend(((target, name), (pos, name)))
        else:
            raise ValueError(f'{path}: invalid WEST tree tag at {pos - 1:#x}')
    return entries


def jobs(files):
    """Group named NVN cache resources by archive; shaders live in this tree."""
    grouped, archives = {}, set()
    for path, rel in files:
        if not path.endswith('.sdftoc'): continue
        folder, stem = os.path.dirname(path), os.path.splitext(os.path.basename(path))[0]
        prefix = os.path.dirname(rel)
        archives.update(p for p, _ in files if os.path.dirname(p) == folder and p.endswith('.sdfdata'))
        for entry in index(path):
            name, archive = entry[:2]
            if '/shadercache/nvn/' not in '/' + name.lower(): continue
            filename = f'{stem}-{chr(65 + archive // 1000)}-{archive:04d}.sdfdata'
            source = os.path.join(folder, filename)
            grouped.setdefault((source, os.path.join(prefix, filename)), []).append(entry)
    if grouped:
        print(f'Snowdrop: {sum(map(len, grouped.values())):,} indexed NVN cache resources in {len(grouped)} archives', flush=True)
    return [(path, rel, entries) for (path, rel), entries in sorted(grouped.items())], archives


def _indexed_records(path, label, entries):
    with open(path, 'rb') as stream:
        for name, _, offset, size, stored, pages in entries:
            stream.seek(offset)
            where = f'{label}:{name}'
            if not pages:
                data = stream.read(size)
            else:
                parts, left = [], size
                for packed in pages:
                    expected = min(65536, left)
                    blob = stream.read(packed or expected)
                    if blob[:4] == ZSTD: blob = _zstd_frame(io.BytesIO(blob))
                    elif packed and packed != expected: blob = zlib.decompress(blob)
                    if len(blob) != expected: raise ValueError(f'{where}: decoded page length mismatch')
                    parts.append(blob); left -= expected
                data = b''.join(parts)
            if len(data) != size: raise ValueError(f'{where}: truncated indexed resource')
            # Native cache envelopes use a second zlib layer. Other serialized
            # resources can begin with the same magic but have metadata here.
            wrapped = len(data) >= 20 and data[:4] == MAGIC
            if wrapped:
                _, kind, flags, _, packed = struct.unpack_from('<5I', data)
                wrapped = not flags and packed == len(data) - 20
            if wrapped: yield from _records(io.BytesIO(data), where)
            else: yield where, None, data


def records(path, label, entries=None):
    if entries is not None:
        yield from _indexed_records(path, label, entries)
        return
    with open(path, 'rb') as stream:
        header = stream.read(0x38)
        if len(header) != 0x38 or header[:4] != b'BERG' or struct.unpack_from('<I', header, 4)[0] != 22:
            raise ValueError(f'{label}: unsupported BERG header/version')
        yield from _records(stream, label, footer=header[8:])
