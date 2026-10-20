# Agent prompt — build the next study guide

Copy everything between the lines into a new Claude Code session, replacing the
`<< >>` placeholders. The agent needs nothing else.

---

You are continuing an iVolve DevOps training repo at `~/iVolve-Tasks`.

**Task:** build a study-guide PDF for << Labs 4–6, tracks: Kubernetes / Jenkins >>,
matching the existing one exactly in design, tone and structure.

**Do this first — do not skip it:**
1. Read `pdf-kit/BUILD-GUIDE.md` in full. It is the complete spec.
2. Open `pdf-kit/labs-1-3.html` — this is the reference implementation.
   Reuse its `<style>` block **verbatim**. Do not redesign anything.
3. Read the lab slides at << path to images >> with the Read tool.
4. Inspect any source repo the labs use, so your explanations match the real code
   rather than what the slide assumes. The Labs 1–3 guide caught two slide errors
   this way — that is expected, not optional.

**Then build it:**
- Author `pdf-kit/labs-<<N-M>>.html` as `<div class="page">` blocks.
- Every lab page opens with a `.ctx` strip and a `.goal` panel (Goal + Done when).
- Fit: `python3 -I measure.py labs-<<N-M>>.html` — **iterate until it prints
  "All pages fit."** A page that overflows is silently clipped; content is lost with
  no error.
- **Then look at EVERY page:** `./shot.sh labs-<<N-M>>.html`, and open each PNG with
  the Read tool. Measuring proves a page fits, not that it reads. This guide shipped
  twice with a layout bug on five pages because only three were spot-checked.
- Read `BUILD-GUIDE.md` §4b "Known pitfalls" before writing CSS. Two of the three
  listed bugs were introduced by a previous agent doing exactly what seemed natural.
- Render last: `./build.sh labs-<<N-M>>.html "<<name>>.pdf"`. It warns if the PDF page
  count differs from the number of `class="page"` divs — that mismatch means clipping.

**Hard rules:**
- The PDF must **not** be committed. `*.pdf` is gitignored — keep it that way.
  Deliver to `~/` and `/mnt/c/Users/eslam/OneDrive/Desktop/iVolve Tasks/`.
- Do not invent command output. If you have not seen the user run it, leave a
  `TODO` marker rather than fabricating a result.
- Keep prose minimal. Tables, callouts and diagrams over paragraphs. The user
  rejected a 19-page prose version; the 11-page visual version replaced it.
- Assume the reader knows nothing. Define each term before using it.
- Explain **why**, not just what — that is what the instructor grades.

**Tone:** direct and concrete. No filler, no praise, no "as we can see".
Flag errors in the lab slides plainly when you find them.

---
