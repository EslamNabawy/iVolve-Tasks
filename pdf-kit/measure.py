#!/usr/bin/env python3
"""Report how full each .page div is, so you can trim before rendering.

    python3 -I measure.py labs-1-3.html [staging-dir]

A4 at 96dpi = 1123px; minus 13mm bottom padding leaves 1074px usable.
We warn at 1050 to leave room for the footer. Pages over the limit are
SILENTLY CLIPPED by overflow:hidden -- there is no error, content just vanishes.
"""
import sys, re, os, glob, subprocess

LIMIT = 1050

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
    sys.exit('Cannot find a writable Windows temp dir under /mnt/c.')

def chrome():
    for p in ('/mnt/c/Program Files/Google/Chrome/Application/chrome.exe',
              '/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'):
        if os.path.exists(p):
            return p
    sys.exit('No Chrome or Edge found on the Windows side.')

src = sys.argv[1] if len(sys.argv) > 1 else sys.exit(__doc__)
wd  = sys.argv[2] if len(sys.argv) > 2 else os.path.join(win_temp(), 'pdfkit')
os.makedirs(wd, exist_ok=True)

js = ('<script>window.addEventListener("load",function(){'
      'var ps=document.querySelectorAll(".page");var o=[];'
      'for(var i=0;i<ps.length;i++){var e=ps[i],ch=e.children,mx=0;'
      'for(var j=0;j<ch.length;j++){if(ch[j].className!="foot"){'
      'var b=ch[j].offsetTop+ch[j].offsetHeight;if(b>mx)mx=b;}}'
      'o.push((i+1)+":"+Math.round(mx));}document.title="M "+o.join(" ");});</script>')

m = os.path.join(wd, 'measure.html')
open(m, 'w', encoding='utf-8').write(
    open(src, encoding='utf-8').read().replace('</body>', js + '</body>'))

win = subprocess.check_output(['wslpath', '-w', m]).decode().strip().replace('\\', '/')
dom = subprocess.run([chrome(), '--headless', '--disable-gpu', '--virtual-time-budget=4000',
                      '--window-size=794,1123', '--dump-dom', f'file:///{win}'],
                     capture_output=True).stdout.decode('utf-8', 'ignore')

hit = re.search(r'M ([\d: ]+)<', dom)
if not hit:
    sys.exit('Could not measure — Chrome returned no title. Is the HTML valid?')

print(f"  page    fill   limit {LIMIT}")
bad = 0
for pair in hit.group(1).split():
    n, h = pair.split(':'); h = int(h)
    if h > LIMIT:
        bad += 1
        print(f"  {n:>4} {h:>7}   OVER by {h-LIMIT}  <-- trim this page")
    else:
        print(f"  {n:>4} {h:>7}   ok")
os.remove(m)
print(f"\n{'All pages fit.' if not bad else str(bad)+' page(s) overflow — trim, then re-run.'}")
sys.exit(1 if bad else 0)
