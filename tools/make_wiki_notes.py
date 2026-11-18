#!/usr/bin/env python3
"""Turn the design chapters in docs/wiki/*.md into src/config/wiki_notes.lua, the Design section
of the in-game Wiki (Field Guide > Wiki > Design). The game can't read .md files in a build
(tools/build_web.sh leaves docs/ and *.md out), so the text is baked into a Lua table.

    python3 tools/make_wiki_notes.py

Run it after editing a chapter. Each chapter's # title is a group in the Wiki list, each ## heading
a page, ### / #### headings are headings on the page. Bullets, tables and code blocks become plain
paragraphs; {{IMG:...}} pictures (for the PDFs) are skipped.
"""
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "docs", "wiki")
OUT = os.path.join(ROOT, "src", "config", "wiki_notes.lua")


def clean(s):
    s = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", s)        # links -> their text
    s = s.replace("**", "").replace("`", "")
    s = re.sub(r"(?<![\w*])\*([^*\n]+)\*(?![\w*])", r"\1", s)  # *italic*
    s = s.replace("{", "(").replace("}", ")")              # braces are key glyphs in Theme.rich
    s = s.replace("&times;", "x").replace("×", "x").replace("→", "->").replace("…", "...").replace("—", ", ").replace("–", "-").replace("·", "-").replace("≤", "<=").replace("≥", ">=").replace("»", ">>").replace("’", "'").replace("“", "\"").replace("”", "\"")
    return s.strip()


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def parse(path):
    lines = open(path, encoding="utf-8").read().split("\n")
    title, pages, page = None, [], None
    para, in_code, code = [], False, []

    def flush():
        if para and page is not None:
            page["blocks"].append({"p": clean(" ".join(para))})
        para.clear()

    def new_page(t):
        nonlocal page
        page = {"title": clean(t), "blocks": []}
        pages.append(page)

    for raw in lines:
        line = raw.rstrip()
        if line.startswith("```"):
            if in_code:
                if page is None:
                    new_page("Introduction")
                page["blocks"].append({"p": clean("\n".join(code)), "color": "dim"})
                code, in_code = [], False
            else:
                flush()
                in_code = True
            continue
        if in_code:
            code.append(line)
            continue
        if line.startswith("{{IMG:"):
            flush()
            continue
        m = re.match(r"^(#+)\s+(.*)$", line)
        if m:
            flush()
            level, text = len(m.group(1)), m.group(2)
            if level == 1:
                title = clean(text)
            elif level == 2:
                new_page(text)
            else:
                if page is None:
                    new_page("Introduction")
                page["blocks"].append({"h": clean(text)})
            continue
        if page is None and line.strip():
            new_page("Introduction")
        if not line.strip():
            flush()
        elif line.lstrip().startswith(("- ", "* ")) or re.match(r"^\s*\d+\.\s", line):
            flush()
            text = re.sub(r"^\s*(?:[-*]|\d+\.)\s+", "", line)
            num = re.match(r"^\s*(\d+)\.\s", line)
            para.append(((num.group(1) + ". ") if num else "- ") + text)
        elif line.startswith("|"):
            flush()
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if all(re.match(r"^:?-{3,}:?$", c) for c in cells):
                # the line under a table header: the header row above was a heading
                blocks = page["blocks"]
                if blocks and "p" in blocks[-1]:
                    blocks[-1] = {"p": blocks[-1]["p"], "color": "accent"}
                continue
            first, rest = cells[0], [c for c in cells[1:] if c]
            page["blocks"].append({"p": clean(first + (": " + ", ".join(rest) if rest else ""))})
        elif para and para[-1].startswith("- ") and raw.startswith("  "):
            para[-1] += " " + line.strip()
        else:
            para.append(line.strip())
    flush()
    return {"title": title or os.path.basename(path), "pages": [p for p in pages if p["blocks"]]}


def main():
    chapters = [parse(p) for p in sorted(glob.glob(os.path.join(SRC, "*.md")))]
    out = ["-- The Design section of the in-game Wiki (src/game/wiki.lua). MADE BY tools/make_wiki_notes.py",
           "-- from docs/wiki/*.md: edit the chapters there and run the tool, not this file.",
           "return {"]
    for ch in chapters:
        out.append("    { title = %s, pages = {" % lua_str(ch["title"]))
        for pg in ch["pages"]:
            out.append("        { title = %s, blocks = {" % lua_str(pg["title"]))
            for b in pg["blocks"]:
                if "h" in b:
                    out.append("            { h = %s }," % lua_str(b["h"]))
                else:
                    col = (", color = %s" % lua_str(b["color"])) if b.get("color") else ""
                    out.append("            { p = %s%s }," % (lua_str(b["p"]), col))
            out.append("        } },")
        out.append("    } },")
    out.append("}")
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print("wrote %s: %d chapters, %d pages" % (os.path.relpath(OUT, ROOT), len(chapters), sum(len(c["pages"]) for c in chapters)))


if __name__ == "__main__":
    main()
