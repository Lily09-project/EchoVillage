"""Fetch only the single-threaded Web export template for Godot 4.5.2.

The official export template bundle is a 1.3 GB zip. This script reads its
central directory with HTTP range requests and downloads just
``templates/web_nothreads_release.zip`` (about 10 MB), verifies its CRC-32 and
pinned SHA-256, and installs it where the Godot editor looks for templates.

Standard library only, so it runs unchanged on CI runners and developer
machines: ``python tools/fetch_web_template.py``.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import struct
import sys
import urllib.request
import zlib
from pathlib import Path

VERSION = "4.5.2.stable"
BUNDLE_URL = "https://github.com/godotengine/godot-builds/releases/download/4.5.2-stable/Godot_v4.5.2-stable_export_templates.tpz"
MEMBER = "templates/web_nothreads_release.zip"
TEMPLATE_NAME = "web_nothreads_release.zip"
# Pinned on first verified download; a mismatch means the upstream file changed.
EXPECTED_SHA256 = "5f202410b79f15d31bfef4c434ee7b7bcc964b50a587bb1338cb53ad9d94c61b"
TAIL_BYTES = 128 * 1024


def default_template_dir() -> Path:
    if sys.platform == "win32":
        base = Path(os.environ["APPDATA"]) / "Godot"
    elif sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support" / "Godot"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "godot"
    return base / "export_templates" / VERSION


def fetch_range(url: str, start: int, end: int) -> bytes:
    request = urllib.request.Request(url, headers={"Range": f"bytes={start}-{end}"})
    with urllib.request.urlopen(request, timeout=120) as response:  # noqa: S310 - fixed https URL
        if response.status != 206:
            raise RuntimeError(f"server ignored the range request (HTTP {response.status})")
        return response.read()


def bundle_size(url: str) -> int:
    request = urllib.request.Request(url, method="HEAD")
    with urllib.request.urlopen(request, timeout=60) as response:  # noqa: S310 - fixed https URL
        return int(response.headers["Content-Length"])


def locate_member(url: str, size: int, name: str) -> tuple[int, int, int, int]:
    """Return (local header offset, compressed size, method, crc32) for one member."""
    tail = fetch_range(url, max(0, size - TAIL_BYTES), size - 1)
    eocd = tail.rfind(b"PK\x05\x06")
    if eocd < 0:
        raise RuntimeError("end of central directory not found")
    _, _, _, _, _, cd_size, cd_offset, _ = struct.unpack("<IHHHHIIH", tail[eocd : eocd + 22])
    directory = fetch_range(url, cd_offset, cd_offset + cd_size - 1)
    position = 0
    while position < len(directory):
        if directory[position : position + 4] != b"PK\x01\x02":
            raise RuntimeError("corrupt central directory")
        fields = struct.unpack("<IHHHHHHIIIHHHHHII", directory[position : position + 46])
        method, crc, compressed = fields[4], fields[7], fields[8]
        name_length, extra_length, comment_length, local_offset = fields[10], fields[11], fields[12], fields[16]
        member = directory[position + 46 : position + 46 + name_length].decode("utf-8")
        if member == name:
            return local_offset, compressed, method, crc
        position += 46 + name_length + extra_length + comment_length
    raise RuntimeError(f"{name} is not in the bundle")


def download_member(url: str, offset: int, compressed: int, method: int, crc: int) -> bytes:
    header = fetch_range(url, offset, offset + 29)
    if header[:4] != b"PK\x03\x04":
        raise RuntimeError("corrupt local header")
    name_length, extra_length = struct.unpack("<HH", header[26:30])
    data_start = offset + 30 + name_length + extra_length
    raw = fetch_range(url, data_start, data_start + compressed - 1)
    if method == 0:
        payload = raw
    elif method == 8:
        payload = zlib.decompress(raw, -15)
    else:
        raise RuntimeError(f"unsupported compression method {method}")
    if zlib.crc32(payload) & 0xFFFFFFFF != crc:
        raise RuntimeError("CRC-32 mismatch")
    return payload


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dest", type=Path, default=None, help="export template directory (defaults to Godot's)")
    args = parser.parse_args(argv)
    destination = (args.dest or default_template_dir()) / TEMPLATE_NAME
    if destination.exists() and hashlib.sha256(destination.read_bytes()).hexdigest() == EXPECTED_SHA256:
        print(f"Web template already installed: {destination}")
        return 0
    size = bundle_size(BUNDLE_URL)
    offset, compressed, method, crc = locate_member(BUNDLE_URL, size, MEMBER)
    payload = download_member(BUNDLE_URL, offset, compressed, method, crc)
    digest = hashlib.sha256(payload).hexdigest()
    if digest != EXPECTED_SHA256:
        print(f"SHA-256 mismatch: expected {EXPECTED_SHA256}, got {digest}", file=sys.stderr)
        return 1
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(payload)
    print(f"Installed {TEMPLATE_NAME} ({len(payload) / 1e6:.1f} MB) to {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
