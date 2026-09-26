"""Store identical exported resources once, preserving all PCK paths and bytes."""

import argparse
import hashlib
import re
import struct
from pathlib import Path


def read_pack(data):
    if data[:4] != b"GDPC" or struct.unpack_from("<I", data, 4)[0] != 4:
        raise ValueError("Expected Godot PCK format 4")
    flags = struct.unpack_from("<I", data, 20)[0]
    if flags != 2:
        raise ValueError("Expected an unencrypted pack with relative offsets")
    base, directory = struct.unpack_from("<QQ", data, 24)
    count = struct.unpack_from("<I", data, directory)[0]
    cursor = directory + 4
    entries = []
    for _ in range(count):
        length = struct.unpack_from("<I", data, cursor)[0]
        cursor += 4
        name = data[cursor : cursor + length]
        cursor += length
        offset, size = struct.unpack_from("<QQ", data, cursor)
        digest = data[cursor + 16 : cursor + 32]
        entry_flags = struct.unpack_from("<I", data, cursor + 32)[0]
        cursor += 36
        if entry_flags or base + offset + size > directory:
            raise ValueError("Unsupported entry or invalid resource bounds")
        content = data[base + offset : base + offset + size]
        if hashlib.md5(content).digest() != digest:
            raise ValueError("Resource checksum mismatch")
        entries.append((name, content, digest))
    if cursor != len(data):
        raise ValueError("Unexpected trailing data")
    return base, entries


def compact(path):
    original = path.read_bytes()
    base, entries = read_pack(original)
    result = bytearray(original[:base])
    stored = {}
    records = []
    for name, content, digest in entries:
        key = hashlib.sha256(content).digest()
        if key not in stored:
            result.extend(b"\0" * (-len(result) % 16))
            stored[key] = len(result) - base
            result.extend(content)
        records.append((name, stored[key], len(content), digest))
    result.extend(b"\0" * (-len(result) % 16))
    struct.pack_into("<Q", result, 32, len(result))
    result.extend(struct.pack("<I", len(records)))
    for name, offset, size, digest in records:
        result.extend(struct.pack("<I", len(name)))
        result.extend(name)
        result.extend(struct.pack("<QQ", offset, size))
        result.extend(digest)
        result.extend(struct.pack("<I", 0))
    _, restored = read_pack(result)
    if restored != entries:
        raise ValueError("Compacted pack did not preserve every resource")
    html_path = path.with_suffix(".html")
    html = None
    if html_path.exists():
        html, replacements = re.subn(
            rf'("{re.escape(path.name)}"\s*:\s*)\d+',
            lambda match: match[1] + str(len(result)),
            html_path.read_text(encoding="utf-8"),
        )
        if replacements != 1:
            raise ValueError("Expected exactly one pack size in the HTML loader")
    path.write_bytes(result)
    if html is not None:
        html_path.write_text(html, encoding="utf-8")
    print(f"Preserved {len(entries)} resources: {len(original):,} -> {len(result):,} bytes")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", type=Path)
    compact(parser.parse_args().pack)
