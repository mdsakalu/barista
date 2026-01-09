#!/usr/bin/env python3
import struct
from pathlib import Path
import sys

if len(sys.argv) < 3:
    print("Usage: make_icns.py <iconset_dir> <output_icns>")
    sys.exit(1)

iconset_dir = Path(sys.argv[1])
output_path = Path(sys.argv[2])

mapping = [
    ("ic11", "icon_32x32.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic13", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic14", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"),
]

chunks = []
for ctype, filename in mapping:
    path = iconset_dir / filename
    if not path.exists():
        print(f"Missing {path}")
        sys.exit(1)
    data = path.read_bytes()
    size = 8 + len(data)
    chunks.append(ctype.encode("ascii") + struct.pack(">I", size) + data)

payload = b"".join(chunks)
file_size = 8 + len(payload)
output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_bytes(b"icns" + struct.pack(">I", file_size) + payload)
print(f"Wrote {output_path}")
