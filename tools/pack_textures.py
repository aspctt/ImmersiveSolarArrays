"""Rebuild the mod's texture pack so every texture ships in one file.

Project Zomboid loads a .pack as an atlas plus a table of named sprites. Every
name in that table becomes a global texture name, and the lookup throws the path
away: getSharedTexture strips the directory and the extension and asks the pack
for what is left. So `getTexture("media/ui/isa_sun.png")` in Lua and `Icon =
SolarPanel` in a script both resolve out of the pack with no code change, as long
as the sprite is named after the file it replaces.

This reads the tile sprites out of the current pack, adds the UI and item icons
from tools/textures, lays them all out on a fresh atlas and writes the pack back.
The tile sprites keep their trim offsets untouched, only their atlas position
moves. Icons are stored whole, with no trim, so a packed icon reports the same
width and height a loose PNG did.

Model textures are the exception and stay loose in common/media/textures. A model
binds its texture whole and samples it with the mesh's own UVs, which run 0 to 1
over the entire image, so a model pointed at an atlas would draw a slice of every
other sprite on the page. The base game ships its 2,253 world item textures loose
for the same reason.

The format, little-endian throughout. Build 42 writes the newer of the two:

    "PZPK"                   newer files only, older ones start at the page count
    int32   version          newer files only, must be 1
    int32   page count
    per page:
        int32 len + bytes    page name
        int32 sprite count
        int32 alpha          nonzero if the page has an alpha channel
        per sprite:
            int32 name len + bytes
            int32 x, y, w, h     rect within the atlas PNG
            int32 offX, offY     offset of that rect within the cell
            int32 cellW, cellH   the sprite's full logical size
        newer: int32 png byte length, then the png
        older: the png, terminated by the bytes EF BE AD DE

Older files are read but never written. Terminating the image with a sentinel
means the loader scans for it a byte at a time, and any pack whose compressed
image happened to contain those four bytes would end early.

Run it after changing any source art:  python tools/pack_textures.py
"""

import io
import os
import struct

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(
    HERE, "..", "ImmersiveSolarArrays", "Contents", "mods",
    "ImmersiveSolarArrays", "common", "media",
)
PACK = os.path.join(MEDIA, "texturepacks", "solarmod_tileset.pack")
SOURCE = os.path.join(HERE, "textures")

SENTINEL = b"\xef\xbe\xad\xde"
PADDING = 2             # transparent gutter, so filtering can't bleed neighbours
MAX_WIDTH = 1024        # the width the base game's own atlas pages stop at


def read_pack(path):
    """Return (page name, alpha, [(name, x, y, w, h, offX, offY, cellW, cellH)], atlas)."""
    d = open(path, "rb").read()

    i = 0
    if d[:4] == b"PZPK":
        i = 4
        version, = struct.unpack_from("<i", d, i)
        i += 4
        if version != 1:
            raise SystemExit(f"unsupported pack version {version}: {path}")

    pages, = struct.unpack_from("<i", d, i)
    i += 4
    if pages != 1:
        raise SystemExit(f"expected a single page, found {pages}")

    n, = struct.unpack_from("<i", d, i)
    i += 4
    name = d[i:i + n].decode()
    i += n

    count, alpha = struct.unpack_from("<ii", d, i)
    i += 8

    sprites = []
    for _ in range(count):
        ln, = struct.unpack_from("<i", d, i)
        i += 4
        sprite = d[i:i + ln].decode()
        i += ln
        sprites.append((sprite,) + struct.unpack_from("<8i", d, i))
        i += 32

    if d[:4] == b"PZPK":
        length, = struct.unpack_from("<i", d, i)
        i += 4
        atlas = d[i:i + length]
        i += length
    else:
        end = d.find(SENTINEL, i)
        if end == -1:
            raise SystemExit(f"no end-of-image marker: {path}")
        atlas = d[i:end]
        i = end + 4

    if i != len(d):
        raise SystemExit(f"{len(d) - i} trailing bytes, format not understood")

    return name, alpha, sprites, Image.open(io.BytesIO(atlas)).convert("RGBA")


def shelf_pack(boxes, max_width):
    """Place (w, h) boxes left to right in rows. Returns positions and size."""
    positions = []
    x = y = row_height = width = 0
    for w, h in boxes:
        if x and x + w + PADDING > max_width:
            x = 0
            y += row_height + PADDING
            row_height = 0
        positions.append((x, y))
        x += w + PADDING
        width = max(width, x - PADDING)
        row_height = max(row_height, h)
    return positions, width, y + row_height


def main():
    page_name, alpha, sprites, atlas = read_pack(PACK)

    # Tile sprites carry trim offsets from whoever packed them first. Keep the
    # offsets, keep the pixels, only the atlas position is allowed to change.
    entries = {}
    for sprite, x, y, w, h, off_x, off_y, cell_w, cell_h in sprites:
        entries[sprite] = {
            "name": sprite,
            "image": atlas.crop((x, y, x + w, y + h)),
            "off": (off_x, off_y),
            "cell": (cell_w, cell_h),
        }

    # Source art wins over whatever is already packed, so this can be run again
    # without the icons piling up or drifting from the files they came from.
    for file in sorted(os.listdir(SOURCE)):
        if not file.endswith(".png"):
            continue
        sprite = os.path.splitext(file)[0]
        if sprite in entries:
            print(f"replacing packed {sprite} with tools/textures/{file}")
        image = Image.open(os.path.join(SOURCE, file)).convert("RGBA")
        entries[sprite] = {
            "name": sprite,
            "image": image,
            "off": (0, 0),
            "cell": image.size,
        }

    # Tallest first packs a lot tighter than source order does.
    entries = sorted(entries.values(), key=lambda e: (-e["image"].height, e["name"]))

    positions, width, height = shelf_pack(
        [e["image"].size for e in entries], MAX_WIDTH)

    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for entry, (x, y) in zip(entries, positions):
        sheet.paste(entry["image"], (x, y))
        entry["pos"] = (x, y)

    buffer = io.BytesIO()
    sheet.save(buffer, format="PNG", optimize=True)
    blob = buffer.getvalue()

    out = bytearray(b"PZPK")
    out += struct.pack("<ii", 1, 1)
    name = page_name.encode()
    out += struct.pack("<i", len(name)) + name
    out += struct.pack("<ii", len(entries), alpha)
    for entry in entries:
        sprite = entry["name"].encode()
        out += struct.pack("<i", len(sprite)) + sprite
        out += struct.pack("<8i", *entry["pos"], *entry["image"].size,
                           *entry["off"], *entry["cell"])
    out += struct.pack("<i", len(blob)) + blob

    before = os.path.getsize(PACK)
    open(PACK, "wb").write(out)

    # Read it straight back, so a bad write never reaches the game.
    _n, _a, written, _atlas = read_pack(PACK)
    assert len(written) == len(entries), "sprite count changed on the way out"
    for entry, got in zip(entries, written):
        assert got[0] == entry["name"], f"{got[0]} != {entry['name']}"
        assert got[3:5] == entry["image"].size, f"{got[0]} changed size"

    print(f"{len(entries)} sprites on a {width}x{height} atlas")
    print(f"{os.path.basename(PACK)}  {before} -> {len(out)} bytes")
    for entry in entries:
        x, y = entry["pos"]
        w, h = entry["image"].size
        print(f"    {entry['name']:<28} {w:>4}x{h:<4} at {x:>4},{y:<4}")


if __name__ == "__main__":
    main()
