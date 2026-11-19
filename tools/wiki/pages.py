import pypdf, json, re, sys, os, glob
D = sys.argv[1]
out = {}
for f in sorted(glob.glob(os.path.join(D, "pdf", "*.pdf"))):
    name = os.path.basename(f)[:-4]
    r = pypdf.PdfReader(f)
    m = {}
    for i, p in enumerate(r.pages, 1):
        t = (p.extract_text() or "").replace("\n", "")
        for a in re.findall(r"QZQ(.+?)QZQ", t):
            m.setdefault(a, i)
    out[name] = m
    print(name, len(r.pages), "pages,", len(m), "anchors")
json.dump(out, open(os.path.join(D, "build", "pages.json"), "w"))
