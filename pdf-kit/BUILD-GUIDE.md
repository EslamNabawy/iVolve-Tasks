# How the study-guide PDF is built

Complete spec for reproducing or extending `iVolve-Labs-1-3-StudyGuide.pdf`.
Written so another agent (or you, in three months) can continue without guessing.

---

## 1. Why this toolchain

No `pandoc`, `wkhtmltopdf`, `weasyprint` or LaTeX is installed, and installing
them needs `sudo`. But **Chrome is already on the Windows side** and WSL can
execute Windows binaries directly. Chrome's print engine does professional
pagination, honours `@page`, and supports flexbox and CSS variables.

So the pipeline is:

```
hand-authored HTML  →  Chrome headless --print-to-pdf  →  A4 PDF
```

**Markdown is deliberately NOT the source.** The first version of this guide was
markdown converted to HTML, and the user rejected it: a converter gives you
default typography and no control over page breaks, side-by-side annotations or
callout boxes. Authoring HTML directly is what makes the design possible.

### The one hard constraint

Chrome is a **Windows** process. It cannot read `/home/...`. Every file it
touches must be staged under `/mnt/c/...` and passed as a `file:///C:/...` URL.
`build.sh` handles this; don't fight it.

---

## 2. Files in this kit

| File | Purpose |
|---|---|
| `labs-1-3.html` | The reference guide. **Copy its `<style>` block verbatim** for new guides. |
| `build.sh` | Renders HTML → PDF. `./build.sh input.html [output.pdf]` |
| `measure.py` | Reports how full each page is. **The critical tool.** |
| `AGENT-PROMPT.md` | Ready-to-paste prompt for a future agent. |

---

## 3. The page model

Each PDF page is one `<div class="page">`. The CSS fixes it at exactly A4:

```css
@page { size: A4; margin: 0; }
.page { width:210mm; height:297mm; padding:13mm 15mm;
        page-break-after:always; overflow:hidden; }
```

### The trap that will bite you

`overflow:hidden` means an overfull page is **silently clipped** — no error, no
warning, content simply vanishes from the PDF. The only defence is measuring.

- A4 at 96 dpi = **1123 px** tall
- minus 13mm bottom padding (49px) = **1074 px** of usable height
- `measure.py` warns at **1050 px**, leaving margin for the footer

**Always check:** PDF page count must equal the number of `class="page"` divs.
`build.sh` prints both and warns on a mismatch. 17 pages from 11 divs means six
pages overflowed.

---

## 4. The build loop

```bash
# 1. measure (staging dir must be under /mnt/c)
python3 -I measure.py labs-1-3.html "/mnt/c/Users/eslam/AppData/Local/Temp/pdfkit"

# 2. trim any page marked OVER, then re-measure. repeat.

# 3. render
./build.sh labs-1-3.html "iVolve-Labs-1-3-StudyGuide.pdf"
```

### Trimming, in order of preference

1. Shorten prose — always the first cut, and usually enough.
2. Drop the least valuable table row.
3. Merge two short paragraphs into one.
4. Last resort: tighten CSS (`.box` padding, `p` margins, `pre` line-height).
   Changing CSS affects **every** page, so re-measure all of them.

### Verify visually before delivering

Measuring proves it fits; it does not prove it looks right. Render single pages
to PNG and actually look at them:

```bash
python3 -I -c "
s=open('labs-1-3.html',encoding='utf-8').read()
css='<style>.page{display:none!important}.page:nth-of-type(4){display:block!important}</style>'
open('/mnt/c/Users/eslam/AppData/Local/Temp/p4.html','w',encoding='utf-8').write(s.replace('</head>',css+'</head>'))"

"/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" --headless --disable-gpu \
  --window-size=794,1123 --screenshot="C:\Users\eslam\AppData\Local\Temp\p4.png" \
  "file:///C:/Users/eslam/AppData/Local/Temp/p4.html"
```

Then open the PNG with the Read tool.

---

## 5. Design system

Defined once in `:root`. Do not introduce new colours.

| Token | Value | Used for |
|---|---|---|
| `--deep` | `#15306B` | Headings, table headers |
| `--primary` | `#1D4ED8` | Accents, rules, step numbers |
| `--green` | `#047857` | "Done when", key insights |
| `--red` | `#BE123C` | Traps |
| `--amber` | `#B45309` | Warnings, slide errors |
| `--code` | `#16233A` | Code block background |

### Components

| Class | Use for |
|---|---|
| `.ph` | Page header — badge + title |
| `.ctx` | Context strip: this lab's IN → OUT and which lab consumes it |
| `.goal` | Two-pane panel: 🎯 Goal (blue) + ✅ Done when (green, `.chk` list) |
| `.box .why` | Blue — why a thing exists |
| `.box .key` | Green — the insight to remember |
| `.box .trap` | Red — a mistake they will make |
| `.box .note` | Amber — caveats, slide errors |
| `.flow` + `.fbox` | Horizontal pipeline diagram with arrows |
| `.steps` + `.step` | Numbered circles with code under each |
| `.anno` | Code left (52%), per-line explanation right |
| `.grid` + `.card` | Two-column comparison (✅ vs ❌) |
| `table` + `caption` | Captioned table; `td.lead-c` tints the first column |
| `.yes` / `.no` | Green ✓ / red ✗ inside tables |

Code highlighting inside `<pre>` is manual spans:
`.k` keyword · `.s` string · `.c` comment · `.p` user-typed input.

---

## 6. Content rules — these came from user feedback

The first attempt was rejected as "soooo bad … so much worthless text". The
rewrite was accepted. What changed:

| Do | Don't |
|---|---|
| Open with **why the labs exist** before any command | Start with installation steps |
| Give every lab an explicit **Goal** + **Done when** checklist | Assume the goal is obvious from the steps |
| Show **IN → OUT** so labs visibly connect | Present labs as unrelated exercises |
| Tables, callouts, diagrams | Paragraphs of prose |
| Annotate code **beside** the lines | Explain code in a block underneath |
| Define every term before use | Assume prior knowledge |
| Explain **why**, since that is what's graded | List what without why |
| State slide errors plainly | Silently "fix" them |
| ~11 pages | ~19 pages of the same content |

**Accuracy beats completeness.** Read the actual source repo before writing about
it. In Labs 1–3 that caught: the app is an interactive CLI with no web server
(so `EXPOSE 8080` is inert and `docker run -i` is mandatory), and the Lab 2 slide
says "Go" for a Java project.

**Never fabricate terminal output.** Use a `TODO` marker instead.

---

## 7. Delivery

- PDF is **gitignored** (`*.pdf`) and must stay out of the repo.
- Deliver to `~/` and `/mnt/c/Users/eslam/OneDrive/Desktop/iVolve Tasks/`.
- This `pdf-kit/` folder **is** committed — it's the reproducible method.

---

## 8. Known-good environment

Ubuntu 24.04 · WSL2 · Chrome at
`/mnt/c/Program Files/Google/Chrome/Application/chrome.exe` (Edge works too).
Python 3 standard library only — no third-party packages.
