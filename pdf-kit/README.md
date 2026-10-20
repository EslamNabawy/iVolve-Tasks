# pdf-kit — how the study-guide PDFs are made

Reproducible toolchain for the iVolve lab study guides. No pandoc, no LaTeX —
it renders hand-authored HTML through Windows Chrome via WSL interop.

| File | What it is |
|---|---|
| **[BUILD-GUIDE.md](BUILD-GUIDE.md)** | The full spec: pipeline, page model, design system, content rules. **Read this first.** |
| **[AGENT-PROMPT.md](AGENT-PROMPT.md)** | Paste-ready prompt to hand a future agent the next set of labs. |
| `labs-1-3.html` | Reference implementation. Copy its `<style>` block verbatim. |
| `build.sh` | `./build.sh input.html [output.pdf]` — renders the PDF. |
| `measure.py` | `python3 -I measure.py input.html` — flags overfull pages. |
| `shot.sh` | `./shot.sh input.html [pages...]` — renders pages to PNG for visual review. |

## Quick start

```bash
python3 -I measure.py labs-1-3.html     # trim until "All pages fit."
./shot.sh labs-1-3.html                 # then LOOK at every page
./build.sh labs-1-3.html "iVolve-Labs-1-3-StudyGuide.pdf"
```

Measuring catches clipping; only looking catches layout bugs. Do both — see
[BUILD-GUIDE.md](BUILD-GUIDE.md) §4b for the ones that have already bitten.

`build.sh` warns if the PDF page count differs from the number of `class="page"`
divs — that mismatch means content overflowed and was **silently clipped**.

The generated PDFs are gitignored on purpose; only the method lives here.
