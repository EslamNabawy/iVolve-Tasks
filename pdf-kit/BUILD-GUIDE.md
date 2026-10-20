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
| `measure.py` | Reports how full each page is. Catches clipping. |
| `shot.sh` | Renders pages to PNG so you can **look** at them. Catches everything else. |
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
# 1. measure — staging dir is auto-detected
python3 -I measure.py labs-1-3.html

# 2. trim any page marked OVER, then re-measure. repeat until "All pages fit."

# 3. LOOK at every page
./shot.sh labs-1-3.html

# 4. render
./build.sh labs-1-3.html "iVolve-Labs-1-3-StudyGuide.pdf"
```

### Trimming, in order of preference

1. Shorten prose — always the first cut, and usually enough.
2. Drop the least valuable table row.
3. Merge two short paragraphs into one.
4. Last resort: tighten CSS (`.box` padding, `p` margins, `pre` line-height).
   Changing CSS affects **every** page, so re-measure all of them.

### Verify visually before delivering — not optional

Measuring proves a page **fits**. It does not prove it **reads**. A page can measure
perfectly and still be unusable (see Pitfall 2 below). Render and look:

```bash
./shot.sh labs-1-3.html          # every page
./shot.sh labs-1-3.html 4 6 9    # just these
```

PNGs land in `./shots/` (gitignored). Open each with the Read tool and actually read it.

**Review every page, not a sample.** The Labs 1–3 guide shipped twice with a layout
bug on five pages because only three pages were spot-checked.

---

## 4b. Known pitfalls — both of these actually happened

### Pitfall 1 — never force `display` when isolating a page

To screenshot one page you must hide the others. Do it like this:

```css
.page:not(:nth-of-type(4)) { display: none !important; }   /* correct */
```

**Not** like this:

```css
.page { display:none !important }
.page:nth-of-type(4) { display:block !important }          /* WRONG */
```

The second form forces `display:block` onto the target, overriding any `display:flex`
it declares. The cover page uses flex centering, so it rendered mis-aligned **only in
the screenshot** — the PDF was always fine. Hours were spent "fixing" a bug that did
not exist. `shot.sh` uses the correct form; use the script.

### Pitfall 2 — flex containers shred inline text

This looked reasonable and rendered as an unreadable grid:

```css
.ctx { display:flex; align-items:center; gap:7px; }
```
```html
<div class="ctx"><span class="pill">LAB 3</span> IN: <code>x.jar</code> → OUT: image</div>
```

Flex turns **every bare text node into its own flex item**, and each one wraps
independently. `IN:` became one column, `x.jar` another, each breaking mid-phrase.

**Rule: a strip of running prose is a block, not a flex container.** Use
`display:block` with `inline-block` pills and `white-space:nowrap` on anything that
must not break:

```css
.ctx { display:block; line-height:1.75; }
.ctx .pill { display:inline-block; white-space:nowrap; }
.ctx code  { white-space:nowrap; }
```

Reserve flex for genuine side-by-side **boxes** (`.goal`, `.grid`, `.flow`, `.anno`),
never for a sentence.

### Pitfall 4 — `overflow:hidden` does not round a table

This looks like it should work, and does not:

```css
table { border-radius:8px; overflow:hidden; }   /* corners stay SHARP */
```

`overflow` is not reliably honoured on `display:table` in print rendering. The
table's own border curves, but the `<th>` background paints straight over the
corners — so some tables looked rounded and others sharp, depending on whether the
corner cell had a background.

**Round the corner cells themselves:**

```css
table { border-collapse:separate; border-spacing:0; border-radius:var(--r); }
thead tr:first-child th:first-child { border-top-left-radius:  calc(var(--r) - 1px); }
thead tr:first-child th:last-child  { border-top-right-radius: calc(var(--r) - 1px); }
tbody tr:last-child  td:first-child { border-bottom-left-radius: calc(var(--r) - 1px); }
tbody tr:last-child  td:last-child  { border-bottom-right-radius:calc(var(--r) - 1px); }
```

`border-collapse:separate` is required — with `collapse`, cell radii are ignored.
The `- 1px` accounts for the table's own 1px border so the curves sit flush.

**Never hard-code a radius.** Use `var(--r)` / `var(--r-sm)`. The guide drifted to six
different values (3, 4, 5, 6, 7, 8px) before this was caught.

### Pitfall 3 — do not describe output you have not seen

The app prints four separate lines. The guide showed them compressed into two
columns, which no real run produces. Read the source or the user's actual terminal
output; if you have neither, write `TODO` rather than inventing a plausible shape.

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
| `--r` | `8px` | Corner radius for **every container**: tables, boxes, cards, `pre`, `.goal`, `.ctx`, `.fbox` |
| `--r-sm` | `4px` | Corner radius for inline chips: `code`, `.pill`, `.tag`, `.ph .n` |

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
