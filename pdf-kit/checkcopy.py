#!/usr/bin/env python3
"""Flag code blocks whose lines SOFT-WRAP.

A wrapped line looks fine in the PDF but pastes as two broken lines, so any
command that wraps is a command the reader cannot copy. Shorten it, or split
it explicitly with a trailing backslash.

    python3 -I checkcopy.py labs-1-3.html
"""
import sys, os, re, glob, subprocess, html as _html

def win_temp():
    try:
        t = subprocess.check_output(['cmd.exe', '/c', 'echo %TEMP%'],
                                    stderr=subprocess.DEVNULL).decode().strip()
        if t and not t.startswith('%'):
            return subprocess.check_output(['wslpath', '-u', t]).decode().strip()
    except Exception:
        pass
    for d in glob.glob('/mnt/c/Users/*/AppData/Local/Temp'):
        if not any(x in d for x in ('Public', 'Default', 'All Users')):
            return d
    sys.exit('No writable Windows temp dir under /mnt/c.')

def chrome():
    for p in ('/mnt/c/Program Files/Google/Chrome/Application/chrome.exe',
              '/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'):
        if os.path.exists(p):
            return p
    sys.exit('No Chrome or Edge found.')

src = sys.argv[1] if len(sys.argv) > 1 else sys.exit(__doc__)
wd = os.path.join(win_temp(), 'pdfkit'); os.makedirs(wd, exist_ok=True)

JS = """
<script>window.addEventListener('load',function(){
  var out=[], pres=document.querySelectorAll('pre');
  for(var i=0;i<pres.length;i++){
    var e=pres[i], cs=getComputedStyle(e);
    var lh=parseFloat(cs.lineHeight);
    var pad=parseFloat(cs.paddingTop)+parseFloat(cs.paddingBottom);
    var logical=e.textContent.replace(/\\n+$/,'').split('\\n').length;
    var actual=Math.round((e.offsetHeight-pad)/lh);
    if(actual>logical){ out.push(i+','+logical+','+actual); }
  }
  document.title='WRAP|'+(out.length?out.join(';'):'none');
});</script>
"""

page = os.path.join(wd, 'checkcopy.html')
open(page, 'w', encoding='utf-8').write(
    open(src, encoding='utf-8').read().replace('</body>', JS + '</body>'))

win = subprocess.check_output(['wslpath', '-w', page]).decode().strip().replace('\\', '/')
dom = subprocess.run([chrome(), '--headless', '--disable-gpu', '--virtual-time-budget=4000',
                      '--window-size=794,1123', '--dump-dom', f'file:///{win}'],
                     capture_output=True).stdout.decode('utf-8', 'ignore')
os.remove(page)

m = re.search(r'WRAP\|([^<"]+)', dom)
if not m:
    sys.exit('Could not read the result — is the HTML valid?')
payload = m.group(1).strip()

# pull the source text of every <pre> so we can name the offender
raw = open(src, encoding='utf-8').read()
blocks = [_html.unescape(re.sub(r'<[^>]+>', '', b)).strip('\n')
          for b in re.findall(r'<pre[^>]*>(.*?)</pre>', raw, re.S)]

if payload == 'none':
    print('All code blocks fit on one line each — every command is copy-safe.')
    sys.exit(0)

print('Code blocks with SOFT-WRAPPED lines (these paste broken):\n')
for item in payload.split(';'):
    idx, logical, actual = (int(x) for x in item.split(','))
    lines = blocks[idx].split('\n') if idx < len(blocks) else ['<unknown>']
    longest = max(lines, key=len)
    print(f'  block #{idx}: {logical} lines render as {actual}  (+{actual-logical} wrapped)')
    print(f'    longest line ({len(longest)} chars): {longest[:88]}')
    print()
print('Fix: shorten the line, or break it yourself with a trailing \\ .')
sys.exit(1)
