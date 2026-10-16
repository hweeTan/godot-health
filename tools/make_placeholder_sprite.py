#!/usr/bin/env python3
"""Draw a 64x64 placeholder runner. No third-party image libraries."""

import struct
import zlib
from pathlib import Path

W = 64
H = 64

OUTLINE = (0x26, 0x12, 0x18, 0xFF)
HAIR = (0xFF, 0x2B, 0xD6, 0xFF)
SKIN = (0xF0, 0xC8, 0xA0, 0xFF)
EYE = (0x1A, 0x10, 0x20, 0xFF)
HOODIE = (0x14, 0x3A, 0x4A, 0xFF)
TEAL = (0x1E, 0xC8, 0xC8, 0xFF)
ACID = (0xC6, 0xFF, 0x4A, 0xFF)
PANTS = (0x2A, 0x20, 0x48, 0xFF)
SHOE = (0xF4, 0xF4, 0xF4, 0xFF)
CLEAR = (0, 0, 0, 0)

pixels = [CLEAR] * (W * H)


def put(x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if 0 <= x < W and 0 <= y < H:
        pixels[y * W + x] = color


def rect(x: int, y: int, w: int, h: int, color: tuple[int, int, int, int]) -> None:
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(xx, yy, color)


def outline_of(color: tuple[int, int, int, int]) -> None:
    filled = [px != CLEAR for px in pixels]
    for y in range(H):
        for x in range(W):
            if filled[y * W + x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and filled[ny * W + nx]:
                    put(x, y, color)
                    break


def draw() -> None:
    # Feet sit near the bottom so the sprite reads as standing on the floor.
    rect(22, 8, 20, 8, HAIR)
    rect(24, 14, 16, 4, HAIR)
    rect(26, 16, 12, 10, SKIN)
    rect(28, 19, 2, 2, EYE)
    rect(34, 19, 2, 2, EYE)
    rect(20, 24, 24, 16, HOODIE)
    rect(22, 26, 4, 12, TEAL)
    rect(38, 26, 4, 12, TEAL)
    rect(30, 28, 4, 8, ACID)
    rect(24, 40, 7, 14, PANTS)
    rect(33, 40, 7, 14, PANTS)
    rect(22, 54, 9, 4, SHOE)
    rect(33, 54, 9, 4, SHOE)
    outline_of(OUTLINE)


def write_png(path: Path) -> None:
    raw = bytearray()
    for y in range(H):
        raw.append(0)
        for x in range(W):
            raw.extend(pixels[y * W + x])

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


if __name__ == "__main__":
    draw()
    destination = Path(__file__).resolve().parents[1] / "art" / "characters" / "runner_placeholder.png"
    write_png(destination)
    print(destination, destination.stat().st_size)
