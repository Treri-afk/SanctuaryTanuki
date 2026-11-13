"""Assemble les previews en une planche : python tools/contact_sheet.py out.png nom1 nom2 ..."""
import sys, os
from PIL import Image, ImageDraw
out, names = sys.argv[1], sys.argv[2:]
d = os.path.join(os.path.dirname(__file__), "..", "assets", "previews")
cell = 420
cols = 4
rows = (len(names) + cols - 1) // cols
sheet = Image.new("RGB", (cols * cell, rows * cell), (40, 40, 44))
dr = ImageDraw.Draw(sheet)
for i, n in enumerate(names):
    p = os.path.join(d, n + ".png")
    if not os.path.exists(p): continue
    im = Image.open(p).convert("RGB").resize((cell, cell))
    x, y = (i % cols) * cell, (i // cols) * cell
    sheet.paste(im, (x, y))
    dr.text((x + 8, y + 6), n, fill=(255, 255, 255))
sheet.save(out)
