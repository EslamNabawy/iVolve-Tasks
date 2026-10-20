#!/usr/bin/env python3
"""Build a new guide that inherits the shared design.

    python3 -I compose.py <style-source.html> <body.html> "<Title>" <out.html>

Copies the <style> block from the reference guide verbatim, so a second document
can never drift from the first. Author only the <div class="page"> blocks in
<body.html> -- no <html>, <head> or <style>.
"""
import sys, re

if len(sys.argv) != 5:
    sys.exit(__doc__)
style_src, body_src, title, out = sys.argv[1:]

m = re.search(r'<style>.*?</style>', open(style_src, encoding='utf-8').read(), re.S)
if not m:
    sys.exit(f'No <style> block found in {style_src}')

body = open(body_src, encoding='utf-8').read().strip()
open(out, 'w', encoding='utf-8').write(
    '<!doctype html><html lang="en"><head><meta charset="utf-8">\n'
    f'<title>{title}</title>\n{m.group(0)}\n</head><body>\n\n{body}\n\n</body></html>\n')

pages = body.count('class="page')
print(f'{out}: {pages} pages, style inherited from {style_src}')
