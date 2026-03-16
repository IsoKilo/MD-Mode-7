from PIL import Image

INPUT = "input.png"
OUTPUT = "output.bin"

img = Image.open(INPUT)

if img.mode != "P":
    raise ValueError("Image must be indexed (palette mode 'P').")

width, height = img.size

if width != 1024 or height != 1024:
    raise ValueError("Image must be exactly 1024x1024.")

pixels = img.load()
data = bytearray()

# discard every other row
for y in range(0, height, 2):

    for x in range(0, width, 2):

        left = pixels[x, y] & 0xF
        right = pixels[x+1, y] & 0xF

        if left == right:
            byte = left
        else:
            byte = (left << 4) | right

        data.append(byte)

with open(OUTPUT, "wb") as f:
    f.write(data)

print("Wrote", len(data), "bytes")