#!/usr/bin/env python3
"""Builds the Swarmed documentation set (HTML per volume) from the game's own data.

data.json + pictures come from the game (src/debug/docdump.lua, run with love --docdump);
file comments are read straight from the content files; hand-written chapters are Markdown
in chapters/. Output: build/<volume>.html, then render.js prints them to PDF.
"""
import html, json, os, re, sys, glob, shutil
import markdown

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(HERE))
# the work folder (data dump, screenshots, HTML, PDFs): WIKI_WORK, default ../swarmed-wiki next to the game
ROOT = os.environ.get("WIKI_WORK") or os.path.join(os.path.dirname(GAME), "swarmed-wiki")
OUT = os.path.join(ROOT, "out")
BUILD = os.path.join(ROOT, "build")
CH = os.path.join(GAME, "docs", "wiki")
os.makedirs(BUILD, exist_ok=True)
D = json.load(open(os.path.join(OUT, "data.json")))
CFG = D["_config"]
FILES = D["_files"]
E = html.escape


def arr(x):
    """The Lua dumper writes arrays with extra keys as dicts keyed "1", "2"..."""
    if isinstance(x, list):
        return x
    if isinstance(x, dict):
        ks = sorted((k for k in x if k.isdigit()), key=int)
        return [x[k] for k in ks]
    return []


# ---------------------------------------------------------------- source comments
_comment_cache = {}


def header_comment(path):
    """Leading comment block of a Lua file, as paragraphs."""
    if not path:
        return ""
    full = os.path.join(GAME, path)
    if full in _comment_cache:
        return _comment_cache[full]
    lines = []
    try:
        for ln in open(full, encoding="utf-8"):
            s = ln.rstrip("\n")
            if s.startswith("--"):
                lines.append(re.sub(r"^--+ ?", "", s))
            elif s.strip() == "" and not lines:
                continue
            else:
                break
    except OSError:
        pass
    txt = "\n".join(lines).strip()
    _comment_cache[full] = txt
    return txt


def split_params(c):
    """Split a header comment into prose and the 'params:' part."""
    m = re.search(r"(?im)^\s*params?\s*:", c)
    if not m:
        return c, ""
    return c[:m.start()].strip(), c[m.start():].strip()


def file_of(kind, id_):
    return FILES.get(kind, {}).get(id_)


def prose(c):
    """Comment text to HTML paragraphs (keeps indented lines as preformatted)."""
    if not c:
        return ""
    out, para, pre = [], [], []
    for ln in c.split("\n"):
        if ln.startswith("  ") or ln.startswith("\t"):
            if para:
                out.append("<p>" + E(" ".join(para)) + "</p>")
                para = []
            pre.append(ln)
            continue
        if pre:
            out.append('<pre class="cm">' + E("\n".join(pre)) + "</pre>")
            pre = []
        if ln.strip() == "":
            if para:
                out.append("<p>" + E(" ".join(para)) + "</p>")
                para = []
        else:
            para.append(ln.strip())
    if para:
        out.append("<p>" + E(" ".join(para)) + "</p>")
    if pre:
        out.append('<pre class="cm">' + E("\n".join(pre)) + "</pre>")
    return "\n".join(out)


# ---------------------------------------------------------------- formatting helpers
STATS = arr(CFG["stats"])
STAT = {s["id"]: s for s in STATS}


def num(v):
    if isinstance(v, bool):
        return "yes" if v else "no"
    if isinstance(v, (int,)):
        return f"{v:,}" if abs(v) >= 10000 else str(v)
    if isinstance(v, float):
        return f"{v:.3g}" if abs(v) < 1000 else f"{v:,.0f}"
    return str(v)


def stat_add(sid, v):
    s = STAT.get(sid, {"label": sid})
    lab = s.get("label", sid)
    if s.get("percent"):
        return f"{'+' if v >= 0 else ''}{num(v)}% {lab}"
    suf = s.get("suffix", "")
    return f"{'+' if v >= 0 else ''}{num(v)}{suf} {lab}"


def stat_mult(sid, v):
    lab = STAT.get(sid, {"label": sid}).get("label", sid)
    return f"{'+' if v >= 0 else ''}{num(round(v * 100, 1))}% {lab}"


def stat_list(stats, mult=None):
    out = []
    if isinstance(stats, dict):
        for k, v in stats.items():
            if isinstance(v, (int, float)):
                out.append(stat_add(k, v))
    if isinstance(mult, dict):
        for k, v in mult.items():
            if isinstance(v, (int, float)):
                out.append(stat_mult(k, v))
    return out


def val(v):
    if isinstance(v, list):
        if v and all(isinstance(x, (int, float)) for x in v) and len(v) in (3, 4) and all(0 <= x <= 1 for x in v):
            return "colour"
        return "{" + ", ".join(val(x) for x in v) + "}"
    if isinstance(v, dict):
        return "{ " + ", ".join(f"{k} = {val(x)}" for k, x in v.items()) + " }"
    if v == "<fn>":
        return "code"
    if isinstance(v, str):
        return v
    return num(v)


def params_line(d, skip=("type", "color", "colour")):
    if not isinstance(d, dict):
        return ""
    parts = []
    for k, v in d.items():
        if k in skip:
            continue
        s = val(v)
        if s == "colour":
            continue
        parts.append(f"<span class='pk'>{E(k)}</span> {E(s)}")
    return " <span class='sep'>·</span> ".join(parts)


def chips(items, cls="chip"):
    return "".join(f"<span class='{cls}'>{E(str(i))}</span>" for i in items)


def swatch(hexcol):
    if not isinstance(hexcol, str) or not hexcol.startswith("#"):
        return ""
    return f"<span class='sw' style='background:{hexcol[:7]}'></span>"


def rgb(c):
    if isinstance(c, list) and len(c) >= 3:
        return "#%02x%02x%02x" % tuple(int(max(0, min(1, x)) * 255) for x in c[:3])
    if isinstance(c, str) and c.startswith("#"):
        return c[:7]
    return "#888"


def img(path, cls="pic", alt=""):
    if path and os.path.exists(path):
        return f"<img class='{cls}' src='file://{path}' alt='{E(alt)}'>"
    return ""


def kv_table(rows, cls="kv"):
    body = "".join(f"<tr><th>{E(k)}</th><td>{v}</td></tr>" for k, v in rows if v not in (None, ""))
    return f"<table class='{cls}'>{body}</table>"


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


# ---------------------------------------------------------------- document model
class Doc:
    def __init__(self, key, title, subtitle):
        self.key, self.title, self.subtitle = key, title, subtitle
        self.parts = []
        self.toc = []        # (level, text, anchor)

    def h(self, level, text, anchor=None, extra=""):
        anchor = anchor or f"{self.key}-{slug(text)}-{len(self.toc)}"
        self.toc.append((level, text, anchor))
        cls = " class='chap'" if level == 1 else ""
        self.parts.append(f"<h{level} id='{anchor}'{cls}>{E(text)}{extra}</h{level}>")
        return anchor

    def add(self, s):
        self.parts.append(s)

    def md(self, name):
        path = os.path.join(CH, name)
        if not os.path.exists(path) and name == "21_custom_bugs.md":
            path = os.path.join(GAME, "docs", "CUSTOM_BUGS.md")
        if not os.path.exists(path) and name == "22_bug_api.md":
            path = os.path.join(GAME, "docs", "BUG_API.md")
        txt = open(path, encoding="utf-8").read()
        txt = re.sub(r"\{\{IMG:([^|}]+)\|?([^}]*)\}\}",
                     lambda m: f"<figure>{img(os.path.join(ROOT, 'shots', m.group(1)), 'shot')}"
                               f"<figcaption>{E(m.group(2))}</figcaption></figure>"
                     if os.path.exists(os.path.join(ROOT, 'shots', m.group(1))) else "", txt)
        h = markdown.markdown(txt, extensions=["tables", "fenced_code", "sane_lists"])

        def repl(m):
            lvl, text = int(m.group(1)), re.sub("<[^>]+>", "", m.group(2))
            text = html.unescape(text)
            anchor = f"{self.key}-{slug(text)}-{len(self.toc)}"
            self.toc.append((lvl, text, anchor))
            cls = " class='chap'" if lvl == 1 else ""
            return f"<h{lvl} id='{anchor}'{cls}>{m.group(2)}</h{lvl}>"
        h = re.sub(r"<h([1-3])>(.*?)</h\1>", repl, h)
        self.parts.append(f"<div class='mdx'>{h}</div>")


# ---------------------------------------------------------------- wiki: characters
def tree_html(tree):
    out = []
    for b in tree.get("branches", []):
        col = rgb(b.get("color"))
        nodes = sorted(b.get("nodes", []), key=lambda n: (n.get("tier", 0), n.get("col", 0)))
        rows = []
        for n in nodes:
            fork = ""
            if n.get("excludes"):
                fork = " <span class='fork'>fork</span>"
            ranks = f" ×{n['ranks']}" if n.get("ranks", 1) > 1 else ""
            rows.append(f"<tr><td class='tier'>T{n.get('tier','')}</td><td><b>{E(n.get('name',''))}</b>{ranks}{fork}</td>"
                        f"<td class='cost'>{n.get('cost','')} pt</td><td>{E(n.get('desc',''))}</td></tr>")
        out.append(f"<div class='branch'><div class='bhead' style='border-color:{col}'><b>{E(b.get('name',''))}</b>"
                   f" <span class='dim'>{E(b.get('blurb',''))}</span></div><table class='nodes'>{''.join(rows)}</table></div>")
    sig = tree.get("signature")
    if isinstance(sig, dict) and sig.get("name"):
        out.append(f"<div class='sig'><b>Signature: {E(sig['name'])}</b> ({sig.get('cost','?')} pt) — {E(sig.get('desc',''))}</div>")
    return "".join(out)


def move_block(label, move, kind):
    if not isinstance(move, dict):
        return ""
    t = move.get("type", "")
    reg = D["attacks"] if kind == "attacks" else D["dashes"]
    mdef = next((m for m in reg if m["id"] == t), {})
    c = header_comment(file_of(kind, t))
    text, params = split_params(c)
    name = move.get("name") or mdef.get("name", t)
    desc = mdef.get("description", "") if kind == "dashes" else ""
    held = []
    if mdef.get("update") and kind == "attacks":
        held.append("has a held / ongoing part")
    if mdef.get("hold"):
        held.append("hold to use")
    if mdef.get("stamina"):
        held.append("stamina mode")
    return (f"<div class='move'><div class='mhead'><span class='mlabel'>{label}</span> <b>{E(name)}</b> "
            f"<code>{E(kind[:-1])}: {E(t)}</code> {chips(held, 'chip dim')}</div>"
            f"{('<p>' + E(desc) + '</p>') if desc else ''}{prose(text)}"
            f"<div class='params'>{params_line(move)}</div></div>")


def wiki_characters(doc):
    doc.h(1, "Playable bugs")
    doc.add(f"<p class='lead'>{len(D['characters'])} playable bugs, generated from <code>content/characters</code>. "
            "Each has an attack, a special, a dash (all shared stamina), a skill tree of three own branches plus a kin "
            "branch and a signature node, and sometimes a bug rule that bends how items work for it. Numbers are the "
            "base values from the character file; skill tree nodes, items and level-up cards change them in a run.</p>")
    fams = {}
    bf = CFG.get("bugfamilies")
    if isinstance(bf, dict) and "list" in bf:
        fams = {f["id"]: f for f in arr(bf["list"])}
    elif isinstance(bf, dict):
        fams = {k: v for k, v in bf.items() if isinstance(v, dict) and "label" in v}
    by_style = not fams
    if by_style:  # no bug families in this build: group by playstyle
        fams = {st["id"]: dict(st, order=i) for i, st in enumerate(arr(CFG["playstyles"].get("styles", [])))}
    famlist = sorted(fams.values(), key=lambda f: f.get("order", 99))

    def fam_of(c):
        if by_style:
            return c.get("playstyle") if c.get("playstyle") in fams else "other"
        if c.get("family") and c["family"] in fams:
            return c["family"]
        for f in famlist:
            if any(t in c.get("tags", []) for t in f.get("tags", [])):
                return f["id"]
        return "other"
    trees = {t["character"]: t for t in D["skilltrees"]}
    rules = CFG.get("bugrules", {})
    unl = CFG.get("unlocks", {})
    starters = set(arr(unl.get("starters", [])))
    unbugs = unl.get("bugs", {})
    styles = CFG["playstyles"].get("byId", {})
    skins = {}
    for s in D["skins"]:
        if s.get("character"):
            skins.setdefault(s["character"], []).append(s["name"])
    # overview table
    rows = []
    for c in sorted(D["characters"], key=lambda c: (fams.get(fam_of(c), {}).get("order", 99), c.get("order", 99))):
        st = c.get("stats", {})
        rows.append(f"<tr><td>{img(os.path.join(OUT,'img/char',c['id']+'.png'),'thumb')}</td><td><b>{E(c['name'])}</b></td>"
                    f"<td>{E(fams.get(fam_of(c),{}).get('label',''))}</td><td>{E(styles.get(c.get('playstyle'),{}).get('label',c.get('playstyle','')))}</td>"
                    f"<td>{st.get('maxHp', STAT['maxHp']['default'])}</td><td>{st.get('armor',0)}</td><td>{st.get('moveSpeed', 100)}</td>"
                    f"<td>{num(c.get('scale',1))}</td><td>{'start' if c['id'] in starters else 'goal'}</td></tr>")
    doc.add("<table class='grid'><tr><th></th><th>Bug</th><th>Family</th><th>Style</th><th>HP</th><th>Armor</th>"
            "<th>Speed</th><th>Size</th><th>Open</th></tr>" + "".join(rows) + "</table>")
    for f in famlist + [{"id": "other", "label": "Other"}]:
        members = [c for c in D["characters"] if fam_of(c) == f["id"]]
        if not members:
            continue
        doc.h(2, f["label"], extra="")
        if f.get("blurb"):
            doc.add(f"<p class='dim'>{E(f['blurb'])}</p>")
        for c in sorted(members, key=lambda c: c.get("order", 99)):
            a = doc.h(3, c["name"], anchor=f"char-{c['id']}")
            st = c.get("stats", {})
            unlock = "Open from the start." if c["id"] in starters else (unbugs.get(c["id"], {}).get("text", "") and "Unlock: " + unbugs[c["id"]]["text"])
            info = [("Id", f"<code>{c['id']}</code>"),
                    ("Tags", chips(c.get("tags", []))),
                    ("Playstyle", E(styles.get(c.get("playstyle"), {}).get("label", c.get("playstyle", "")) + " — " + styles.get(c.get("playstyle"), {}).get("desc", ""))),
                    ("Stats", " · ".join(E(x) for x in stat_list(st)) or "defaults"),
                    ("Body", f"radius {num(c.get('radius',6))} · scale {num(c.get('scale',1))}" + (" · flies" if "flyer" in c.get("tags", []) else "")),
                    ("Unlock", E(unlock or "")),
                    ("Starting items", E(", ".join(c.get("startingItems", [])))),
                    ("Skins", E(", ".join(skins.get(c["id"], [])))),
                    ("Music", E(str(c.get("music", ""))) if c.get("music") else ""),
                    ("Frenzy", E(c.get("frenzy", "")) if c.get("frenzy") else "")]
            r = rules.get(c["id"])
            if r:
                info.append(("Bug rule", f"<b>{E(r.get('name',''))}</b>: {E(r.get('description',''))}"))
            doc.add(f"<div class='card'><div class='cardpic'>{img(os.path.join(OUT,'img/char',c['id']+'.png'))}</div>"
                    f"<div class='cardbody'><p class='desc'>{E(c.get('description',''))}</p>"
                    f"{('<p class=lore>' + E(c['lore']) + '</p>') if c.get('lore') else ''}"
                    f"{('<p class=tip>Tip: ' + E(re.sub(r'[{}]', '', c['tip'])) + '</p>') if c.get('tip') else ''}"
                    f"{kv_table(info)}</div></div>")
            doc.add(move_block("Attack", c.get("attack"), "attacks"))
            doc.add(move_block("Special", c.get("secondary"), "attacks"))
            doc.add(move_block("Dash", c.get("dash"), "dashes"))
            t = trees.get(c["id"])
            if t:
                doc.add("<h4>Skill tree</h4>" + tree_html(t))


# ---------------------------------------------------------------- wiki: enemies
def wiki_enemies(doc):
    fams = arr(CFG["families"])
    beh = {b["id"]: b for b in D["behaviors"]}
    doc.h(1, "Enemies")
    nq = sum(1 for e in D["enemies"] if e.get("boss"))
    doc.add(f"<p class='lead'>{len(D['enemies'])} enemies ({nq} of them queens or bosses), generated from "
            "<code>content/enemies</code>. Each entry lists its stats, when it first spawns, its behaviour "
            "(the AI file in <code>content/behaviors</code>, with the parameters this species passes it) and its "
            "text. HP and damage are base values: modes, danger, wave growth, elites and pacing scale them.</p>")
    doc.add("<p class='dim'>Spawn: <b>min wave</b> is the earliest wave it can be introduced (the run shuffles the order "
            "a little), <b>weight</b> how common it is once known, <b>group</b> a multiplier on group size. "
            "Bite rate is seconds between bites while touching you (default 1).</p>")
    for f in fams:
        members = [e for e in D["enemies"] if e.get("family") == f["id"]]
        if not members:
            continue
        doc.h(2, f["label"])
        lineup = os.path.join(ROOT, "shots", f"art_fam_{f['id']}.png")
        if os.path.exists(lineup):
            doc.add(f"<figure>{img(lineup, 'shot')}<figcaption>The {E(f['label'].lower())} lined up in the arena</figcaption></figure>")
        queens = [e for e in members if e.get("behavior") == "queen"]
        members = [e for e in members if e.get("behavior") != "queen"]
        rows = []
        for e in sorted(members, key=lambda e: (bool(e.get("boss")), e["spawn"].get("minWave", 1), e["name"])):
            rows.append(f"<tr><td>{img(os.path.join(OUT,'img/enemy',e['id']+'.png'),'thumb')}</td><td>{E(e['name'])}</td>"
                        f"<td>{num(e['hp'])}</td><td>{num(e['damage'])}</td><td>{num(e['speed'])}</td><td>{num(e['xp'])}</td>"
                        f"<td>{'queen/boss' if e.get('boss') else e['spawn'].get('minWave','')}</td><td>{E(beh.get(e['behavior'],{}).get('name',e['behavior']))}</td></tr>")
        doc.add("<table class='grid'><tr><th></th><th>Name</th><th>HP</th><th>Dmg</th><th>Speed</th><th>XP</th>"
                "<th>From wave</th><th>Behaviour</th></tr>" + "".join(rows) + "</table>")
        for e in sorted(members, key=lambda e: (bool(e.get("boss")), e["spawn"].get("minWave", 1), e["name"])):
            doc.h(3, e["name"], anchor=f"enemy-{e['id']}")
            b = beh.get(e["behavior"], {})
            bc = header_comment(file_of("behaviors", e["behavior"]))
            btext, bparams = split_params(bc)
            sp = e.get("spawn", {})
            flags = []
            for k, lab in (("solid", "solid (blocks movement)"), ("shield", "shield head"), ("venom", "venomous"),
                           ("noElites", "never elite"), ("noStun", "can't be stunned"), ("encounter", "boss encounter"),
                           ("light", "glows")):
                if e.get(k):
                    flags.append(lab)
            if e.get("onDeath"):
                flags.append("death effect")
            rows = [("Id", f"<code>{e['id']}</code>"),
                    ("Stats", f"HP {num(e['hp'])} · damage {num(e['damage'])} · speed {num(e['speed'])} · radius {num(e['radius'])} · mass {num(e['mass'])} · XP {num(e['xp'])}"
                     + (f" · bite every {num(e['biteRate'])} s" if e.get('biteRate') else "") + (f" · scale {num(e['scale'])}" if e.get('scale', 1) != 1 else "")),
                    ("Spawn", "only as a queen / boss" if e.get("boss") or sp.get("weight", 0) == 0 else
                     f"min wave {sp.get('minWave',1)} · weight {sp.get('weight',10)} · group ×{num(sp.get('groupSize',1))}"),
                    ("Tags", chips(e.get("tags", []))),
                    ("Traits", E(", ".join(flags))),
                    ("Behaviour", f"<b>{E(b.get('name', e['behavior']))}</b> <code>{E(e['behavior'])}</code>"
                     + (f"<div class='params'>{params_line(e.get('behaviorParams'))}</div>" if e.get("behaviorParams") else "")),
                    ("Colours", "gibs " + "".join(swatch(g) for g in e.get("gibs", [])) + " splat " + swatch(e.get("splat")))]
            if isinstance(e.get("elites"), dict) and e["elites"]:
                rows.append(("Elite twists", E(", ".join(e["elites"].keys()))))
            doc.add(f"<div class='card'><div class='cardpic'>{img(os.path.join(OUT,'img/enemy',e['id']+'.png'))}</div>"
                    f"<div class='cardbody'><p class='desc'>{E(e.get('description',''))}</p>"
                    f"{('<p class=lore>' + E(e['lore']) + '</p>') if e.get('lore') else ''}"
                    f"{('<p class=tip>Tip: ' + E(e['tip']) + '</p>') if e.get('tip') else ''}"
                    f"{kv_table(rows)}"
                    f"{('<div class=howworks><b>How the behaviour works.</b> ' + prose(btext) + '</div>') if btext else ''}"
                    f"</div></div>")
        if queens:
            doc.h(3, f"{f['single']} queens")
            qb = header_comment(file_of("behaviors", "queen"))
            doc.add(f"<div class='howworks'><b>How queens work.</b> {prose(split_params(qb)[0])}</div>")
            qrows = []
            for e in sorted(queens, key=lambda e: e["name"]):
                bp = e.get("behaviorParams", {})
                brood = next((x["name"] for x in D["enemies"] if x["id"] == bp.get("brood")), bp.get("brood", ""))
                qrows.append(f"<tr><td>{img(os.path.join(OUT,'img/enemy',e['id']+'.png'),'thumb')}</td><td><b>{E(e['name'])}</b><br><code>{e['id']}</code></td>"
                             f"<td>{num(e['hp'])} HP · {num(e['damage'])} dmg · speed {num(e['speed'])}</td>"
                             f"<td>{E(brood)} ×{bp.get('count','')} every {bp.get('interval','')} s</td><td>{E(e.get('description',''))}</td></tr>")
            doc.add("<table class='grid'><tr><th></th><th>Queen</th><th>Stats</th><th>Lays</th><th>Description</th></tr>" + "".join(qrows) + "</table>")

    # behaviours
    doc.h(2, "Enemy behaviours (AI)")
    doc.add("<p>Every behaviour is a file in <code>content/behaviors</code> with <code>update(e, world, dt, params)</code> "
            "that sets the enemy's desired velocity (<code>e.mx, e.my</code>), plus optional <code>init</code>, "
            "<code>onHit</code> (react to being hit, returns a damage multiplier), <code>draw</code> (telegraphs, shown "
            "with Attack Warnings on) and <code>drawUnder</code>. Helpers live in <code>src/game/ai.lua</code>.</p>")
    users = {}
    for e in D["enemies"]:
        users.setdefault(e["behavior"], []).append(e["name"])
    for b in sorted(D["behaviors"], key=lambda b: b["name"]):
        hooks = [k for k in ("init", "onHit", "draw", "drawUnder") if b.get(k)]
        c = header_comment(file_of("behaviors", b["id"]))
        text, params = split_params(c)
        doc.add(f"<div class='entry'><div class='ehead'><b>{E(b['name'])}</b> <code>{E(b['id'])}</code> {chips(hooks,'chip dim')}</div>"
                f"{prose(text)}{('<pre class=cm>' + E(params) + '</pre>') if params else ''}"
                f"<div class='used'>Used by: {E(', '.join(users.get(b['id'], [])) or 'other behaviours / elites only')}</div></div>")

    # elites
    doc.h(2, "Elite affixes")
    doc.add("<p>From wave 2 any ant can roll an elite affix (Risk of Rain style): tinted, bigger, glowing, standing on a "
            "coloured aura. Files in <code>content/elites</code>; a species can give an affix its own twist with "
            "<code>elites = { id = { params = {...} } }</code>.</p>")
    rows = []
    for el in D["elites"]:
        mods = []
        for k in ("hp", "damage", "speed", "mass", "scale"):
            if el.get(k, 1) != 1:
                mods.append(f"{k} ×{num(el[k])}")
        if el.get("armor"):
            mods.append(f"armor {num(el['armor']*100)}%")
        if el.get("bonusXP"):
            mods.append(f"bonus XP {num(el['bonusXP'])}")
        rows.append(f"<tr><td>{swatch(el.get('color'))} <b>{E(el['name'])}</b></td><td>{E(el.get('description',''))}</td>"
                    f"<td>{E(', '.join(mods))}</td><td>{el.get('minWave',1)}</td><td>{el.get('weight',10)}</td></tr>")
    doc.add("<table class='grid'><tr><th>Affix</th><th>What it does</th><th>Numbers</th><th>From</th><th>Weight</th></tr>" + "".join(rows) + "</table>")

    # bosses & hazards
    doc.h(2, "Boss encounters and stage hazards")
    doc.add(prose(header_comment("content/enemies/predators.lua")))
    for bo in D["bosses"]:
        kind = "Stage hazard (can't be fought)" if bo.get("hazard") else "Boss fight: " + bo.get("enemy", "")
        c = header_comment(file_of("bosses", bo["id"]))
        rows = [("Kind", E(kind)), ("From wave", str(bo.get("minWave", ""))), ("Arrives", f"{bo['arrive']} s into the wave" if bo.get("arrive") else ""),
                ("Stays", f"{bo['stay']} s at most" if bo.get("stay") else ""), ("XP", str(bo.get("xp", "")))]
        pics = sorted(glob.glob(os.path.join(ROOT, "shots", f"hz_{bo['id']}_*.png")))[:4]
        if bo["id"] == "antlion":
            pics = [os.path.join(ROOT, "shots", "art_antlion.png")]
        gallery = "<div class='gallery'>" + "".join(img(p_, "gal") for p_ in pics) + "</div>" if pics else ""
        doc.add(f"<div class='entry'><div class='ehead'><b>{E(bo.get('title', bo['name']))}</b> <code>{E(bo['id'])}</code></div>"
                f"<p class='desc'>{E(bo.get('description',''))}</p>{prose(c)}{kv_table(rows)}{gallery}</div>")
    q = CFG["bosses"]
    doc.add("<h4>Queens, the Empress and champions</h4>"
            + kv_table([("Queen enrage", E(params_line(q.get("enrage")) and re.sub('<[^>]+>', '', params_line(q.get('enrage'))))),
                        ("Empress phases", E(", ".join(f"{int(x*100)}%" for x in arr(q.get('empressPhases', []))))),
                        ("Champion waves", E(", ".join(str(x) for x in arr(q.get('championWaves', []))))),
                        ("Champion", E(re.sub('<[^>]+>', '', params_line(q.get('champion'))))),
                        ("Champion names", E(", ".join(arr(q.get("championNames", [])))))]))
    ep = q.get("epithets", {})
    if ep:
        doc.add("<p class='dim'>Queen epithets by map: " + "; ".join(f"<b>{E(k)}</b>: {E(', '.join(arr(v)))}" for k, v in ep.items()) + "</p>")


# ---------------------------------------------------------------- wiki: items & progression
def wiki_items(doc):
    cats = CFG["categories"]
    catlist = sorted((v for v in cats.values() if isinstance(v, dict) and "label" in v), key=lambda c: c.get("order", 0)) \
        if isinstance(cats, dict) else []
    if isinstance(cats, dict) and "order" in cats:
        catlist = [cats[i] for i in arr(cats["order"]) if isinstance(cats.get(i), dict)]
    rar = CFG["rarities"]
    rarlist = sorted((dict(v, id=k) for k, v in rar.items() if isinstance(v, dict)), key=lambda r: r.get("order", 0))
    tags = CFG["tags"]
    molts_into, molts_from = {}, {}
    for m in D["molts"]:
        molts_into[m["into"]] = m
        for f in m["from"]:
            molts_from.setdefault(f, []).append(m)
    names = {i["id"]: i["name"] for i in D["items"]}
    packs = {}
    for sh in arr(CFG["amber"].get("shelves", [])):
        for p in arr(sh.get("list", [])):
            for it in arr(p.get("items", [])):
                packs[it] = p.get("name")
    locked = CFG["unlocks"].get("items", {})

    doc.h(1, "Items")
    doc.add(f"<p class='lead'>{len(D['items'])} items, generated from <code>content/items</code>. Everything in the bag counts "
            "(no equipping); copies stack; the limit is fitting shapes into the grid. An item's <b>category</b> says what it is "
            "for, its <b>tags</b> drive set bonuses and synergy hints, its <b>procs</b> fire on triggers.</p>")
    doc.h(2, "Rarities")
    doc.add("<table class='grid'><tr><th>Rarity</th><th>Weight in choices</th><th>From wave</th><th>Eaten heals</th></tr>" +
            "".join(f"<tr><td>{swatch(r.get('color'))} {E(r.get('label', r['id']))}</td><td>{r.get('weight')}</td><td>{r.get('minWave')}</td><td>{r.get('eat')} HP</td></tr>" for r in rarlist) + "</table>")
    doc.h(2, "Categories")
    doc.add("<table class='grid'><tr><th>Category</th><th>Meaning</th></tr>" +
            "".join(f"<tr><td>{swatch(c.get('color'))} {E(c['label'])}</td><td>{E(c.get('blurb',''))}</td></tr>" for c in catlist) + "</table>")
    doc.h(2, "Tags and set bonuses")
    doc.add("<p>Three items sharing a tag, all touching in one group in the bag, give the tag's set bonus; five give it twice.</p>")
    doc.add("<table class='grid'><tr><th>Tag</th><th>Set</th><th>Bonus</th></tr>" +
            "".join(f"<tr><td>{swatch(t.get('color'))} {E(t.get('label',k))}</td><td>{E(t.get('set',{}).get('name',''))}</td>"
                    f"<td>{E(', '.join(stat_list(t.get('set',{}).get('stats'), t.get('set',{}).get('statsMult'))))}</td></tr>"
                    for k, t in sorted(tags.items()) if isinstance(t, dict)) + "</table>")

    def shape_svg(it):
        cells = it.get("cells", [])
        if not cells:
            return ""
        w = max(c[0] for c in cells) + 1
        h = max(c[1] for c in cells) + 1
        s = 9
        rects = "".join(f"<rect x='{c[0]*s}' y='{c[1]*s}' width='{s-1}' height='{s-1}'/>" for c in cells)
        return f"<svg class='shape' width='{w*s}' height='{h*s}'>{rects}</svg>"

    for cat in catlist + [{"id": None, "label": "Other"}]:
        members = [i for i in D["items"] if i.get("category") == cat["id"]] if cat["id"] else \
            [i for i in D["items"] if i.get("category") not in {c["id"] for c in catlist}]
        if not members:
            continue
        doc.h(2, f"{cat['label']} items")
        if cat.get("blurb"):
            doc.add(f"<p class='dim'>{E(cat['blurb'])}</p>")
        order = {r["id"]: r.get("order", 0) for r in rarlist}
        for it in sorted(members, key=lambda i: (order.get(i["rarity"], 9), i["name"])):
            r = rar.get(it["rarity"], {})
            procs = []
            for p in it.get("procs", []):
                ch = p.get("chance")
                procs.append(f"{p.get('trigger')}" + (f" ({num(round(ch*100,1))}%)" if isinstance(ch, (int, float)) else "")
                             + (f", cooldown {num(p['cooldown'])} s" if p.get("cooldown") else ""))
            extras = []
            for k in ("shopSpeed", "freeShopRerolls", "rarityBump", "beadValue", "enemySpeed", "interestCap", "waveNectar",
                      "poisonAmp", "cardsDelta", "noEatHeal"):
                if k in it:
                    extras.append(f"{k} {val(it[k])}")
            mo = []
            if it["id"] in molts_from:
                for m in molts_from[it["id"]]:
                    mo.append("molts with " + " + ".join(names.get(x, x) for x in m["from"] if x != it["id"]) + " → " + names.get(m["into"], m["into"]))
            if it["id"] in molts_into:
                m = molts_into[it["id"]]
                mo.append("made by molting " + " + ".join(names.get(x, x) for x in m["from"]))
            effect = it.get("effect") if isinstance(it.get("effect"), str) and it.get("effect") != "<fn>" else it.get("effect_eval")
            rows = [("Rarity", f"{swatch(r.get('color'))} {E(r.get('label', it['rarity']))}"),
                    ("Shape", shape_svg(it) + f" <span class='dim'>{len(it.get('cells',[]))} cell(s)</span>"),
                    ("Price", f"{it.get('price')} nectar"),
                    ("Stats", E(" · ".join(stat_list(it.get("stats"), it.get("statsMult"))))),
                    ("Procs", E("; ".join(procs))),
                    ("Tags", chips(it.get("tags", []))),
                    ("Molting", E("; ".join(mo))),
                    ("Other", E(", ".join(extras))),
                    ("Curse", E(it["curse"]) if isinstance(it.get("curse"), str) else ("yes" if it.get("curse") else "")),
                    ("Locked", E(locked[it["id"]].get("text", "")) if it["id"] in locked and isinstance(locked[it["id"]], dict) else ""),
                    ("Burrow pack", E(packs.get(it["id"], "")))]
            doc.add(f"<div class='icard'><div class='ipic'>{img(os.path.join(OUT,'img/item',it['id']+'.png'))}</div>"
                    f"<div class='cardbody'><div class='ehead' id='item-{it['id']}'><b>{E(it['name'])}</b> <code>{E(it['id'])}</code></div>"
                    f"<p class='desc'>{E(it.get('description',''))}</p>"
                    f"{('<p class=effect>' + E(effect) + '</p>') if effect and effect != it.get('description') else ''}"
                    f"{kv_table(rows)}</div></div>")
    doc.h(2, "Molting recipes")
    doc.add("<p>Items whose pieces touch in the bag molt into a stronger item when a queen wave is cleared "
            "(<code>content/molts</code>). Molted items are never dealt in item choices.</p>")
    doc.add("<table class='grid'><tr><th>Pieces</th><th>Becomes</th><th>Hint</th></tr>" + "".join(
        f"<tr><td>{E(' + '.join(names.get(x, x) for x in m['from']))}</td><td><b>{E(names.get(m['into'], m['into']))}</b></td><td>{E(m.get('hint') or '')}</td></tr>"
        for m in D["molts"]) + "</table>")


def wiki_progression(doc):
    doc.h(1, "Progression")
    # level cards
    doc.h(2, "Level-up cards")
    doc.add(prose(header_comment("content/levelcards/_template.lua")))
    fam = {}
    for c in D["levelcards"]:
        fam.setdefault(c.get("family", "stat"), []).append(c)
    for f, cards in fam.items():
        doc.add(f"<h4>{E(f.title())} cards</h4>")
        rows = []
        for c in sorted(cards, key=lambda c: c["name"]):
            txt = c.get("text_eval") or c.get("scaledText_eval") or c.get("description") or c.get("description_eval") or ""
            s = " · ".join(stat_list(c.get("stats"), c.get("statsMult")))
            cost = c.get("cost")
            if isinstance(cost, dict):
                s += "  (cost: " + ", ".join(stat_list(cost.get("stats"), cost.get("statsMult"))) + ")"
            g = c.get("growth")
            if isinstance(g, dict):
                s += " per wave: " + ", ".join(stat_list(g.get("stats"), g.get("statsMult")))
            rows.append(f"<tr><td><b>{E(c['name'])}</b></td><td>{E(txt or s)}</td><td>{c.get('minLevel',1)}</td><td>{c.get('weight',10)}</td>"
                        f"<td>{c.get('maxRank','')}</td></tr>")
        doc.add("<table class='grid'><tr><th>Card</th><th>Effect (common roll)</th><th>Min level</th><th>Weight</th><th>Max rank</th></tr>" + "".join(rows) + "</table>")
    # kin branches
    doc.h(2, "Kin branches")
    doc.add("<p>The fourth skill tree branch, shared by a lineage of bugs and matched by character tags and priority "
            "(<code>content/skillbranches</code>). Each tree tops it with its own signature node.</p>")
    for b in sorted(D["skillbranches"], key=lambda b: -b.get("priority", 0)):
        nodes = b.get("nodes", [])
        nodes = arr(nodes) if not isinstance(nodes, list) else nodes
        rows = "".join(f"<tr><td class='tier'>T{n.get('tier','')}</td><td><b>{E(n.get('name',''))}</b></td><td class='cost'>{n.get('cost','')} pt</td><td>{E(n.get('desc',''))}</td></tr>" for n in sorted(nodes, key=lambda n: (n.get('tier', 0), n.get('col', 0))))
        doc.add(f"<div class='branch'><div class='bhead' style='border-color:{rgb(b.get('color'))}'><b>{E(b['name'])}</b> "
                f"<span class='dim'>{E(b.get('blurb',''))} · tags {E(', '.join(b.get('tags', [])))}</span></div><table class='nodes'>{rows}</table></div>")
    # artifacts
    doc.h(2, "Artifacts")
    doc.add("<p>Run rules bought once with amber in the Burrow and switched on before a run (<code>content/artifacts</code>).</p>")
    doc.add("<table class='grid'><tr><th>Artifact</th><th>Rule</th><th>Amber</th></tr>" + "".join(
        f"<tr><td>{swatch(a.get('color'))} <b>{E(a['name'])}</b></td><td>{E(a['description'])}</td><td>{a.get('cost')}</td></tr>"
        for a in sorted(D["artifacts"], key=lambda a: a.get("order", 50))) + "</table>")
    # keepsakes
    doc.h(2, "Keepsakes")
    doc.add("<p>One small trade a bug carries into a run, bought with amber and picked in mode select "
            "(<code>src/config/keepsakes.lua</code>).</p>")
    doc.add("<table class='grid'><tr><th>Keepsake</th><th>Trade</th><th>Amber</th></tr>" + "".join(
        f"<tr><td>{swatch(k.get('color'))} <b>{E(k['name'])}</b></td><td>{E(k['description'])}</td><td>{k.get('cost')}</td></tr>"
        for k in arr(CFG["keepsakes"])) + "</table>")
    # amber
    doc.h(2, "Amber and the Burrow")
    ea = CFG["amber"].get("earn", {})
    doc.add("<p>Amber is earned by every real run: " + ", ".join(f"{E(k)} {num(v)}" for k, v in ea.items()) + ".</p>")
    for sh in arr(CFG["amber"].get("shelves", [])):
        doc.add(f"<h4>Shelf: {E(sh.get('name', sh.get('id','')))}</h4>")
        doc.add("<table class='grid'><tr><th>Unlock</th><th>What</th><th>Amber</th></tr>" + "".join(
            f"<tr><td><b>{E(p.get('name',''))}</b></td><td>{E(p.get('description',''))}"
            + (f" <span class='dim'>({E(', '.join(arr(p.get('items', []))))})</span>" if p.get("items") else "")
            + f"</td><td>{p.get('cost','')}</td></tr>" for p in arr(sh.get("list", []))) + "</table>")
    # danger
    doc.h(2, "Danger levels")
    dg = CFG["danger"]
    doc.add("<table class='grid'><tr><th>Level</th><th>Name</th><th>Adds</th></tr>" + "".join(
        f"<tr><td>{k}</td><td>{swatch(v.get('color'))} {E(v.get('name',''))}</td><td>{E(v.get('description',''))}</td></tr>"
        for k, v in sorted(((k, v) for k, v in dg.items() if isinstance(v, dict)), key=lambda x: int(x[0]))) + "</table>")
    # unlocks
    doc.h(2, "Unlocks")
    un = CFG["unlocks"]
    doc.add("<p>Starters: " + E(", ".join(arr(un.get("starters", [])))) + ".</p>")
    doc.add("<table class='grid'><tr><th>Unlocks</th><th>Goal</th></tr>" + "".join(
        f"<tr><td>{E(k)}</td><td>{E(v.get('text',''))}</td></tr>" for k, v in sorted(un.get("bugs", {}).items())) +
        "".join(f"<tr><td>item: {E(k)}</td><td>{E(v.get('text',''))}</td></tr>" for k, v in sorted(un.get("items", {}).items()) if isinstance(v, dict)) + "</table>")
    # achievements
    doc.h(2, "Achievements")
    cats = {}
    for a in D["achievements"]:
        cats.setdefault(a.get("category", "Misc"), []).append(a)
    doc.add(f"<p>{len(D['achievements'])} achievements (<code>content/achievements</code>); several files generate entries from other content.</p>")
    for c, lst in cats.items():
        doc.add(f"<h4>{E(c)}</h4><table class='grid compact'>" + "".join(
            f"<tr><td><b>{E(a['name'])}</b>{' (hidden)' if a.get('hidden') else ''}</td><td>{E(a.get('description',''))}</td><td>{num(a.get('goal',1))}</td></tr>"
            for a in sorted(lst, key=lambda a: a.get("order", 0))) + "</table>")
    # skins & decor
    doc.h(2, "Skins and map decor")
    doc.add("<table class='grid'><tr><th>Skin</th><th>For</th><th>Look</th></tr>" + "".join(
        f"<tr><td><b>{E(s['name'])}</b></td><td>{E(s.get('character') or 'any bug')}</td><td>{E(s.get('description',''))}</td></tr>" for s in D["skins"]) + "</table>")
    doc.add("<table class='grid'><tr><th>Decor</th><th>Look</th></tr>" + "".join(
        f"<tr><td><b>{E(s['name'])}</b></td><td>{E(s.get('description',''))}</td></tr>" for s in D["decor"]) + "</table>")


# ---------------------------------------------------------------- wiki: world
def simple_entries(doc, kind, title, intro, extra=None):
    doc.h(2, title)
    if intro:
        doc.add(f"<p>{intro}</p>")
    for d in sorted(D[kind], key=lambda d: (d.get("order", 50), d.get("name", d["id"]))):
        c = header_comment(file_of(kind, d["id"]))
        text, params = split_params(c)
        desc = d.get("description") if isinstance(d.get("description"), str) else ""
        rows = extra(d) if extra else []
        col = d.get("color")
        doc.add(f"<div class='entry'><div class='ehead'>{swatch(rgb(col)) if col else ''}<b>{E(d.get('name', d['id']))}</b> <code>{E(d['id'])}</code></div>"
                f"{('<p class=desc>' + E(desc) + '</p>') if desc else ''}"
                f"{prose(text) if text and text != desc else ''}"
                f"{kv_table(rows) if rows else ''}</div>")


def wiki_world(doc):
    doc.h(1, "Maps, events and run pieces")
    doc.h(2, "Maps (stages)")
    shots = sorted(glob.glob(os.path.join(ROOT, "shots", "map_*.png")))
    names = {e["id"]: e["name"] for e in D["enemies"]}
    for st in sorted(D["stages"], key=lambda s: s.get("order", 50)):
        pal = st.get("palette", {})
        fauna = st.get("fauna", {})
        fz = ", ".join(f"{names.get(k, k)} ×{num(v)}" for k, v in fauna.items() if k != "first")
        rows = [("Id", f"<code>{st['id']}</code>"), ("Arena", f"{st.get('size')} units square"),
                ("Opens wave 1", E(names.get(fauna.get("first"), fauna.get("first", "")) if fauna.get("first") else "")),
                ("Wildlife", E(fz)), ("Props", E(", ".join(f"{k} ×{v}" for k, v in st.get("props", {}).items()))),
                ("Events", E(", ".join(f"{k} ×{num(v)}" for k, v in st.get("events", {}).items()) if isinstance(st.get("events"), dict) else "")),
                ("Weather", E(", ".join(f"{k} ×{num(v)}" for k, v in st.get("weather", {}).items()) if isinstance(st.get("weather"), dict) else "")),
                ("Mechanic", E(st.get("mechanic", {}).get("type", "") if isinstance(st.get("mechanic"), dict) else "")),
                ("Wave pacing", E(re.sub('<[^>]+>', '', params_line(st.get("spawn"))))),
                ("Palette", "".join(swatch(v) for v in pal.values() if isinstance(v, str)))]
        pic = os.path.join(ROOT, "shots", f"map_{st['id']}.png")
        doc.add(f"<div class='entry'><div class='ehead'><b>{E(st['name'])}</b></div><p class='desc'>{E(st.get('description',''))}</p>"
                f"{img(pic, 'mapshot')}{kv_table(rows)}</div>")
    simple_entries(doc, "mechanics", "Stage mechanics", "Rules a map turns on with <code>mechanic = { type = ... }</code>.")
    simple_entries(doc, "events", "Mid-wave events", "From wave 2 a wave gets 0–2 events, 6–24 s in (<code>content/events</code>). They never hold a wave up.",
                   lambda d: [("From wave", str(d.get("minWave"))), ("Weight", str(d.get("weight"))), ("Kind", E(str(d.get("kind", "")))),
                              ("Lasts", f"{d['duration']} s" if isinstance(d.get("duration"), (int, float)) else "")])
    simple_entries(doc, "props", "Props", "Things in the arena that are neither player nor enemy (<code>content/props</code>). Never hold a wave up.",
                   lambda d: [("Radius / mass", f"{num(d.get('radius'))} / {num(d.get('mass',''))}" if d.get("mass") else num(d.get("radius"))),
                              ("Pushable", "yes" if d.get("pushable") else ""), ("Crush damage", num(d["damage"]) if d.get("damage") else ""),
                              ("Map gamble", E(re.sub('<[^>]+>', '', params_line(d.get("gamble")))) if isinstance(d.get("gamble"), dict) else "")])
    simple_entries(doc, "weather", "Weather spells", "Passing spells of rain, fog, wind, pollen and so on (<code>content/weather</code>). Effects push, slow or speed the fight.",
                   lambda d: [("Lasts", E(val(d.get("duration")))), ("Effects", E(val(d.get("effects"))) if d.get("effects") else ""),
                              ("Wind", E(val(d.get("wind"))) if d.get("wind") else ""), ("Weight", str(d.get("weight")))])
    simple_entries(doc, "wavemods", "Wave modifiers", "Rolled ahead per wave from wave 3, never on queen or final waves (<code>content/wavemods</code>).",
                   lambda d: [("From wave", str(d.get("minWave"))), ("Weight", str(d.get("weight"))),
                              ("Changes", E(", ".join(f"{k} {val(d[k])}" for k in ("groupSize", "hp", "damage", "speed", "elites", "formation", "ambush", "entryStyles") if k in d)))])
    simple_entries(doc, "routes", "Route gates", "Two tunnels after a wave: safe or hard (<code>content/routes</code>).",
                   lambda d: [("Kind", E(d.get("kind", ""))), ("Ants ×", num(d.get("groupMul"))), ("Elites ×", num(d.get("eliteMul"))),
                              ("Health ×", num(d.get("hpMul"))), ("Reward", E(val(d.get("reward"))) if d.get("reward") else "")])
    simple_entries(doc, "goals", "Mini-goals", "Optional side tasks some waves bring (<code>content/goals</code>).",
                   lambda d: [("Text", E(d.get("text") if isinstance(d.get("text"), str) else "")), ("From wave", str(d.get("minWave"))),
                              ("Reward", E(val(d.get("reward"))))])
    simple_entries(doc, "pickups", "Ground pickups", "Glowing tokens dropped by ants and elites (<code>content/pickups</code>).",
                   lambda d: [("Source", E(str(d.get("source")))), ("From wave", str(d.get("minWave"))), ("Weight", str(d.get("weight")))])
    simple_entries(doc, "frenzies", "Frenzy super moves", "What a full frenzy meter unleashes (<code>content/frenzies</code>).",
                   lambda d: [("Tags", chips(d.get("tags", []))), ("Params", params_line(d.get("params")))])
    simple_entries(doc, "streaks", "Kill-streak buffs", "A short random buff every 50 kills in one combo (<code>content/streaks</code>).",
                   lambda d: [("Buff", E(", ".join(stat_list(d.get("stats"), d.get("statsMult"))))), ("Lasts", f"{d.get('time')} s"),
                              ("Needs combo", str(d.get("minCombo", "")))])
    # modes
    doc.h(1, "Game modes")
    doc.add("<p>Modes are files in <code>content/modes</code>; each reshapes the waves on top of the map's own settings.</p>")
    for m in sorted(D["modes"], key=lambda m: m.get("order", 50)):
        rows = [("Id", f"<code>{m['id']}</code>"), ("Group", E(m.get("group", ""))),
                ("Final wave", "never ends" if m.get("finalWave") is False else str(m.get("finalWave"))),
                ("Enemy health / damage", f"×{num(m.get('enemyHp',1))} / ×{num(m.get('enemyDamage',1))}" + (f", +{num(m['hpPerWave']*100)}% HP per wave" if m.get("hpPerWave") else "")),
                ("Families", E(", ".join(m.get("families", [])) if isinstance(m.get("families"), list) else "")),
                ("Wave settings", E(re.sub('<[^>]+>', '', params_line(m.get("spawn"))))),
                ("Elites", E(val(m.get("elites"))) if m.get("elites") else ""),
                ("Boss pool", E(", ".join(m.get("bossPool", []))) if m.get("bossPool") else ""),
                ("Flags", E(", ".join(k for k in ("endless", "custom", "hidden", "tutorial", "chooseItems", "queensAnyWave") if m.get(k)))),
                ("Scripted waves", f"{len(m['waves'])} hand-made waves" if isinstance(m.get("waves"), list) else "")]
        doc.add(f"<div class='entry'><div class='ehead'><b>{E(m['name'])}</b> <span class='dim'>{E(m.get('tagline',''))}</span></div>"
                f"<p class='desc'>{E(m.get('description',''))}</p>{kv_table(rows)}</div>")


# ---------------------------------------------------------------- reference
def wiki_reference(doc):
    doc.h(1, "Reference tables")
    doc.h(2, "Player stats")
    doc.add("<p><code>src/config/stats.lua</code>. Final value = (base + sum of adds) × (1 + sum of multipliers), clamped.</p>")
    doc.add("<table class='grid'><tr><th>Stat</th><th>Id</th><th>Default</th><th>Limits</th><th>What the number means</th></tr>" + "".join(
        f"<tr><td><b>{E(s['label'])}</b></td><td><code>{s['id']}</code></td><td>{num(s.get('default'))}{'%' if s.get('percent') else s.get('suffix','')}</td>"
        f"<td>{E(', '.join(x for x in [('min ' + num(s['min'])) if 'min' in s else '', ('max ' + num(s['max'])) if 'max' in s else '', ('soft cap ' + val(s['soft'])) if s.get('soft') else '', 'lower is better' if s.get('lowerIsBetter') else ''] if x))}</td>"
        f"<td>{E(D['_statInfo'].get(s['id'], ''))}</td></tr>" for s in STATS) + "</table>")
    doc.h(2, "Settings")
    sch = arr(CFG["settings_schema"])
    bycat = {}
    for s in sch:
        bycat.setdefault(s.get("category", "Other"), []).append(s)
    doc.add(f"<p>{len(sch)} settings, every one from <code>src/config/settings_schema.lua</code> (the settings screen is generated from it).</p>")
    for c, lst in bycat.items():
        doc.add(f"<h4>{E(c)}</h4><table class='grid compact'><tr><th>Setting</th><th>Key</th><th>Default</th><th>What it does</th></tr>" + "".join(
            f"<tr><td><b>{E(s.get('label',''))}</b></td><td><code>{E(s.get('key',''))}</code></td><td>{E(val(s.get('default')))}</td><td>{E(s.get('desc',''))}</td></tr>"
            for s in lst) + "</table>")
    doc.h(2, "Developer console commands")
    doc.add("<table class='grid compact'><tr><th>Command</th><th>Usage</th><th>Does</th></tr>" + "".join(
        f"<tr><td><code>{E(c['name'])}</code></td><td><code>{E(c.get('usage',''))}</code></td><td>{E(c.get('help',''))}</td></tr>" for c in D["_commands"]) + "</table>")
    doc.h(2, "Attacks and specials")
    users = {}
    for c in D["characters"]:
        for slot in ("attack", "secondary"):
            if isinstance(c.get(slot), dict):
                users.setdefault(c[slot].get("type"), []).append(c["name"])
    for a in sorted(D["attacks"], key=lambda a: a["name"]):
        text, params = split_params(header_comment(file_of("attacks", a["id"])))
        doc.add(f"<div class='entry'><div class='ehead'><b>{E(a['name'])}</b> <code>{E(a['id'])}</code></div>{prose(text)}"
                f"{('<pre class=cm>' + E(params) + '</pre>') if params else ''}<div class='used'>Used by: {E(', '.join(users.get(a['id'], [])) or 'Bug Creator / scripts')}</div></div>")
    doc.h(2, "Dashes")
    users = {}
    for c in D["characters"]:
        if isinstance(c.get("dash"), dict):
            users.setdefault(c["dash"].get("type"), []).append(c["name"])
    for a in sorted(D["dashes"], key=lambda a: a["name"]):
        text, params = split_params(header_comment(file_of("dashes", a["id"])))
        doc.add(f"<div class='entry'><div class='ehead'><b>{E(a['name'])}</b> <code>{E(a['id'])}</code></div>"
                f"{('<p class=desc>' + E(a['description']) + '</p>') if a.get('description') else ''}{prose(text) if text != a.get('description') else ''}"
                f"{('<pre class=cm>' + E(params) + '</pre>') if params else ''}<div class='used'>Used by: {E(', '.join(users.get(a['id'], [])) or 'Bug Creator / scripts')}</div></div>")
    doc.h(2, "Content folders and their schemas")
    doc.add("<p>Every folder in <code>content/</code> has a commented <code>_template.lua</code>; these are the schema notes from each.</p>")
    for k in sorted(FILES):
        t = os.path.join(GAME, "content", k, "_template.lua")
        if os.path.exists(t):
            doc.add(f"<h4>content/{E(k)} <span class='dim'>({len(D.get(k, []))} entries)</span></h4><pre class='code'>{E(open(t, encoding='utf-8').read())}</pre>")


# ---------------------------------------------------------------- page
CSS = open(os.path.join(HERE, "style.css"), encoding="utf-8").read().replace("FONTDIR", os.path.join(GAME, "assets/fonts"))


def page(doc, vol_no, pages=None, total_title="Swarmed Design Bible"):
    toc = []
    for lvl, text, anchor in doc.toc:
        if lvl > (3 if doc.key in ("bug", "ene") else 2):
            continue
        pn = pages.get(anchor, "") if pages else ""
        toc.append(f"<div class='toc{lvl}'><a href='#{anchor}'>{E(text)}</a><span class='pn'>{pn}</span></div>")
    pick = {"eng": "cover_1.png", "sty": "cover_2.png", "bug": "cover_3.png", "ene": "cover_4.png",
            "itm": "item_icons_sheet.png", "wld": "map_wildflower_meadow.png", "ref": "cover_1.png"}.get(doc.key, "cover.png")
    cover_img = os.path.join(ROOT, "shots", pick)
    if not os.path.exists(cover_img):
        cover_img = os.path.join(ROOT, "shots", "cover.png")
    cover = (f"<section class='cover'><div class='cbg' style=\"background-image:url('file://{cover_img}')\"></div>"
             f"<div class='ctext'><div class='kicker'>{E(total_title)} · Volume {vol_no}</div><h1 class='ctitle'>{E(doc.title)}</h1>"
             f"<div class='csub'>{E(doc.subtitle)}</div><div class='cfoot'>Swarmed · LÖVE2D / Lua · documented from the code on 18 November 2026</div></div></section>")
    body = ''.join(doc.parts)
    body = re.sub(r"(<table class='grid[^']*'>)(<tr>(?:<th>.*?</th>)+</tr>)", r"\1<thead>\2</thead>", body)
    if os.environ.get("MARK"):
        body = re.sub(r"(<h([123]) id='([^']+)'[^>]*>)", lambda m: m.group(1) + f"<span class='mark'>QZQ{m.group(3)}QZQ</span>", body)
    return (f"<!doctype html><html><head><meta charset='utf-8'><title>{E(doc.title)}</title><style>{CSS}</style></head><body>"
            f"{cover}<section class='toc'><h2 class='tochead'>Contents</h2>{''.join(toc)}</section>"
            f"<main>{body}</main></body></html>")


VOLS = []


def build():
    v = Doc("eng", "Engine & Systems", "How the game boots, runs, draws and plays: every system and how they connect")
    for f in ("01_overview.md", "02_engine.md", "03_gameplay.md", "04_runs.md", "05_meta.md", "06_tools.md", "07_spinoff.md"):
        if os.path.exists(os.path.join(CH, f)):
            v.md(f)
    VOLS.append(v)
    v = Doc("sty", "Style Guide", "Art, animation, UI, sound, feel and writing: what makes it look and play like Swarmed")
    if os.path.exists(os.path.join(CH, "10_style.md")):
        v.md("10_style.md")
    VOLS.append(v)
    v = Doc("bug", "Wiki: Playable Bugs", "Every character: moves, stats, rules and full skill trees")
    wiki_characters(v)
    VOLS.append(v)
    v = Doc("ene", "Wiki: Enemies & Bosses", "Every ant, bee, wasp, hornet, termite, queen and predator, with how its AI works")
    wiki_enemies(v)
    VOLS.append(v)
    v = Doc("itm", "Wiki: Items & Progression", "Items, molting, sets, level-up cards, kin branches, meta progression")
    wiki_items(v)
    wiki_progression(v)
    VOLS.append(v)
    v = Doc("wld", "Wiki: World & Modes", "Maps, mechanics, events, hazards, props, weather, wave modifiers and modes")
    wiki_world(v)
    VOLS.append(v)
    v = Doc("ref", "Reference", "Stats, settings, console, every attack and dash, content schemas")
    wiki_reference(v)
    if os.path.exists(os.path.join(CH, "21_custom_bugs.md")) or os.path.exists(os.path.join(GAME, "docs", "CUSTOM_BUGS.md")):
        v.md("21_custom_bugs.md")
    if os.path.exists(os.path.join(CH, "22_bug_api.md")) or os.path.exists(os.path.join(GAME, "docs", "BUG_API.md")):
        v.md("22_bug_api.md")       # the full Bug Creator API reference
    VOLS.append(v)


if __name__ == "__main__":
    build()
    os.makedirs(BUILD, exist_ok=True)
    pages = {}
    pf = os.path.join(BUILD, "pages.json")
    if os.path.exists(pf):
        pages = json.load(open(pf))
    manifest = []
    for i, v in enumerate(VOLS, 1):
        name = f"{i:02d}_{slug(v.title)}"
        open(os.path.join(BUILD, name + ".html"), "w", encoding="utf-8").write(page(v, i, pages.get(name)))
        manifest.append({"name": name, "title": v.title, "anchors": [a for l, t, a in v.toc if l <= 3]})
    json.dump(manifest, open(os.path.join(BUILD, "manifest.json"), "w"))
    print("built", [m["name"] for m in manifest])
