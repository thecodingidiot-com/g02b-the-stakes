#!/bin/bash
# Generate the tileset and sprite sheet for g02b.
#
# tileset.png: 4 tiles, 32x32 each, side by side (128x32 total).
#   index 0 (src.x=0)   -- ground (brown)
#   index 1 (src.x=32)  -- platform (green)
#   index 2 (src.x=64)  -- coin (gold circle) -- new in g02b
#   index 3 (src.x=96)  -- hazard (red spikes) -- new in g02b
#
# spritesheet.png: 4 frames, 28x44 each, side by side (112x44 total).
#   frame 0 -- idle
#   frame 1, 2 -- walk cycle
#   frame 3 -- jump
#
# Unchanged from g02a: player sprite sheet, ground/platform tiles.

set -e

mkdir -p assets

python3 - <<'EOF'
from PIL import Image, ImageDraw

TILE = 32
tileset = Image.new("RGB", (TILE * 4, TILE), (0, 0, 0))
d = ImageDraw.Draw(tileset)
d.rectangle([0, 0, TILE - 1, TILE - 1], fill=(0x8b, 0x5a, 0x2b))       # ground
d.rectangle([TILE, 0, TILE * 2 - 1, TILE - 1], fill=(0x2e, 0x8b, 0x57))  # platform

# coin -- gold circle on the platform-green background so it reads as
# a pickup sitting on a tile, not a tile of its own
d.rectangle([TILE * 2, 0, TILE * 3 - 1, TILE - 1], fill=(0x2e, 0x8b, 0x57))
d.ellipse([TILE * 2 + 8, 8, TILE * 3 - 9, TILE - 9], fill=(0xff, 0xd7, 0x00),
    outline=(0xb8, 0x86, 0x0b))

# hazard -- three red spike triangles on the ground-brown background
d.rectangle([TILE * 3, 0, TILE * 4 - 1, TILE - 1], fill=(0x8b, 0x5a, 0x2b))
x0 = TILE * 3
for i in range(3):
    sx = x0 + i * 11
    d.polygon([(sx, TILE - 1), (sx + 5, TILE - 1), (sx + 2, 8)],
        fill=(0xcc, 0x22, 0x22))

tileset.save("assets/tileset.png")
print("  wrote assets/tileset.png")

FW, FH = 28, 44
sheet = Image.new("RGBA", (FW * 4, FH), (0, 0, 0, 0))
d = ImageDraw.Draw(sheet)

def draw_frame(i, leg_a_top, leg_b_top):
    x0 = i * FW
    d.ellipse([x0 + 8, 0, x0 + FW - 9, 10], fill=(0xf0, 0xc8, 0xa0))    # head
    d.rectangle([x0 + 6, 10, x0 + FW - 7, 26], fill=(0xd4, 0x33, 0x33)) # torso
    d.rectangle([x0 + 8, leg_a_top, x0 + 13, 40], fill=(0x2b, 0x2b, 0x2b))
    d.rectangle([x0 + FW - 14, leg_b_top, x0 + FW - 9, 40], fill=(0x2b, 0x2b, 0x2b))

draw_frame(0, 26, 26)   # idle -- both legs level
draw_frame(1, 26, 32)   # walk A -- left leg forward
draw_frame(2, 32, 26)   # walk B -- right leg forward
draw_frame(3, 30, 30)   # jump -- legs tucked up together

sheet.save("assets/spritesheet.png")
print("  wrote assets/spritesheet.png")
EOF
