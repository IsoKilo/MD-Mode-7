from PIL import Image

INPUT = "Map.png"
OUTPUT = "Map.bin"

img = Image.open(INPUT)

if img.mode != "P":
    raise ValueError("Image must be indexed (mode 'P').")
if img.size != (256, 256):
    raise ValueError("Image must be exactly 256x256.")
pixels = img.load()
data = bytearray()

for y in range(0, 256, 2):
    for x in range(0, 256, 2):
        left = pixels[x, y] & 0xF
        right = pixels[x + 1, y] & 0xF
        data.append((left << 4) | right)

with open(OUTPUT, "wb") as f:
    f.write(data)

print("Wrote", len(data), "bytes")