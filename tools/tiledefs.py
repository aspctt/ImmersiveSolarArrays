"""Read and write TileZed .tiles files.

Layout, little endian ints, strings terminated by a newline rather than length prefixed:

    "tdef", int version, int numTilesets
    per tileset:
        str name, str imageSource, int columns, int rows, int unknown, int numTiles
        per tile, in index order:
            int numProperties
            per property: str name, str value        (value is often empty)
"""
import struct
import sys


class Reader:
    def __init__(self, data):
        self.d = data
        self.o = 0

    def i32(self):
        v = struct.unpack_from("<i", self.d, self.o)[0]
        self.o += 4
        return v

    def s(self):
        end = self.d.index(b"\n", self.o)
        v = self.d[self.o:end].decode("utf-8")
        self.o = end + 1
        return v


def parse(path):
    r = Reader(open(path, "rb").read())
    assert r.d[:4] == b"tdef", "not a tiledef file"
    r.o = 4
    version = r.i32()
    tilesets = []
    for _ in range(r.i32()):
        ts = {"name": r.s(), "image": r.s(), "cols": r.i32(), "rows": r.i32(),
              "unknown": r.i32()}
        ts["tiles"] = []
        for _ in range(r.i32()):
            props = []
            for _ in range(r.i32()):
                key = r.s()
                props.append([key, r.s()])
            ts["tiles"].append(props)
        tilesets.append(ts)
    assert r.o == len(r.d), "trailing bytes: consumed %d of %d" % (r.o, len(r.d))
    return version, tilesets


def build(version, tilesets):
    out = [b"tdef", struct.pack("<i", version), struct.pack("<i", len(tilesets))]
    for ts in tilesets:
        out.append(ts["name"].encode("utf-8") + b"\n")
        out.append(ts["image"].encode("utf-8") + b"\n")
        out.append(struct.pack("<iii", ts["cols"], ts["rows"], ts["unknown"]))
        out.append(struct.pack("<i", len(ts["tiles"])))
        for props in ts["tiles"]:
            out.append(struct.pack("<i", len(props)))
            for key, value in props:
                out.append(key.encode("utf-8") + b"\n")
                out.append(value.encode("utf-8") + b"\n")
    return b"".join(out)


if __name__ == "__main__":
    path = sys.argv[1]
    version, tilesets = parse(path)
    original = open(path, "rb").read()
    identical = build(version, tilesets) == original
    print("version %d, %d tileset(s)" % (version, len(tilesets)))
    for ts in tilesets:
        used = sum(1 for p in ts["tiles"] if p)
        print("  %s (%s) %dx%d, %d tile slots, %d with properties"
              % (ts["name"], ts["image"], ts["cols"], ts["rows"], len(ts["tiles"]), used))
    print("round trip:", "IDENTICAL" if identical else "DIFFERENT")
    if len(sys.argv) > 2:
        want = sys.argv[2]
        for ts in tilesets:
            for i, props in enumerate(ts["tiles"]):
                if props and (want == "all" or want == str(i)):
                    print("  %s_%d" % (ts["name"], i))
                    for k, v in props:
                        print("      %-20s = %s" % (k, v))
