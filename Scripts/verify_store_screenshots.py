#!/usr/bin/env python3
"""Check final upload PNG integrity, pixel sizes, opacity, sRGB profile and manifest."""
import argparse
import hashlib
import json
import struct
import zlib
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--write-manifest', action='store_true')
args = parser.parse_args()
base = Path(__file__).resolve().parents[1] / 'Marketing/AppStore'
records = []
for platform, expected in [('macOS', (2880, 1800)), ('iPadOS', (2064, 2752))]:
    files = sorted((base / 'ko-KR' / platform).glob('*.png'))
    assert 1 <= len(files) <= 10, platform
    for path in files:
        data = path.read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n', path
        cursor, chunks = 8, {}
        while cursor < len(data):
            length = struct.unpack('>I', data[cursor:cursor+4])[0]
            kind = data[cursor+4:cursor+8]
            payload = data[cursor+8:cursor+8+length]
            crc = struct.unpack('>I', data[cursor+8+length:cursor+12+length])[0]
            assert zlib.crc32(kind + payload) & 0xffffffff == crc, path
            chunks[kind] = payload
            cursor += length + 12
        width, height, depth, color = struct.unpack('>IIBB', chunks[b'IHDR'][:10])
        assert (width, height) == expected and depth == 8 and color == 2, path
        assert b'tRNS' not in chunks and b'IEND' in chunks, path
        assert b'sRGB' in chunks or b'sRGB' in chunks.get(b'iCCP', b''), path
        records.append(dict(file=str(path.relative_to(base)), width=width, height=height,
                            colorSpace='sRGB', alpha=False, sha256=hashlib.sha256(data).hexdigest()))
manifest = base / 'screenshots.json'
if args.write_manifest:
    manifest.write_text(json.dumps(records, indent=2, ensure_ascii=False) + '\n')
else:
    assert json.loads(manifest.read_text()) == records, '스크린샷 매니페스트와 파일이 일치하지 않음'
print(f'업로드 스크린샷 {len(records)}장: 크기·RGB·투명도·파일 무결성 검증 통과')
