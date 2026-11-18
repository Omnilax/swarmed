#!/usr/bin/env python3
"""Join the volume PDFs into 00_swarmed-design-bible-complete.pdf, one bookmark per volume."""
import glob, json, os, sys
from pypdf import PdfWriter, PdfReader

work = sys.argv[1]
manifest = json.load(open(os.path.join(work, "build", "manifest.json")))
w = PdfWriter()
for v in manifest:
    path = os.path.join(work, "pdf", v["name"] + ".pdf")
    start = len(w.pages)
    for p in PdfReader(path).pages:
        w.add_page(p)
    w.add_outline_item(v["title"], start)
out = os.path.join(work, "pdf", "00_swarmed-design-bible-complete.pdf")
with open(out, "wb") as f:
    w.write(f)
print("wrote", out, len(w.pages), "pages")
