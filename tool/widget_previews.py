# Regenerates the widget-picker previews (android/app/src/main/res/drawable-nodpi/widget_preview_*.png).
# Usage (Chrome installed, design bundle present):
#   python tool/widget_previews.py build/previews bad-habits-tracking-app/project/_ds/nocturne-5fcf7eca-d5ec-4cd9-9b64-493360c47c32/styles.css
#   then for each printed "name w h":
#   chrome --headless=new --hide-scrollbars --default-background-color=00000000 --force-device-scale-factor=3
#          --virtual-time-budget=8000 --window-size=w,h --screenshot=widget_preview_name.png build/previews/name.html
import os, sys, pathlib

out = pathlib.Path(sys.argv[1])
css = pathlib.Path(sys.argv[2]).as_uri()  # Nocturne styles.css

head = f'''<!doctype html><html><head><meta charset="utf-8">
<link rel="stylesheet" href="{css}">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500&display=block">
<link rel="stylesheet" href="https://unpkg.com/@phosphor-icons/web@2.1.1/src/regular/style.css">
<link rel="stylesheet" href="https://unpkg.com/@phosphor-icons/web@2.1.1/src/fill/style.css">
<style>html,body{{margin:0;background:transparent;font-family:var(--font-body);color:var(--color-text)}}
.w{{border-radius:26px;background:color-mix(in srgb,var(--color-surface) 86%,transparent);box-shadow:var(--shadow-sm)}}</style>
</head><body>'''
FAIL = 'oklch(0.76 0.11 18)'

pages = {
    'ring': (153, 153, f'''
<div class="w" style="width:153px;height:153px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px">
  <div style="width:92px;height:92px;border-radius:46px;background:conic-gradient(var(--color-accent) 100%,var(--color-neutral-800) 0);display:flex;align-items:center;justify-content:center">
    <div style="width:80px;height:80px;border-radius:40px;background:var(--color-surface);display:flex;flex-direction:column;align-items:center;justify-content:center">
      <i class="ph ph-device-mobile" style="font-size:16px;color:var(--color-accent-300)"></i>
      <div style="font-size:16px;font-weight:500;letter-spacing:-0.02em;font-variant-numeric:tabular-nums">7h 48m</div>
    </div>
  </div>
  <div style="font-size:11.5px;color:var(--color-accent-300)">Beaten ✓</div>
</div>'''),
    'streak': (153, 153, '''
<div style="width:153px;height:153px;box-sizing:border-box;border-radius:26px;background:linear-gradient(160deg,var(--color-section-ghost),var(--color-section));box-shadow:var(--shadow-sm);padding:16px 16px 14px;display:flex;flex-direction:column">
  <div style="display:flex;align-items:center;gap:6px;font-size:30px;font-weight:500;color:var(--color-accent-200)"><i class="ph-fill ph-flame"></i>4</div>
  <div style="font-size:11px;color:var(--color-accent-200);margin-top:-2px">longer in a row</div>
  <div style="flex:1"></div>
  <div style="font-size:22px;font-weight:500;letter-spacing:-0.02em;color:var(--color-neutral-100);font-variant-numeric:tabular-nums">3h 54m</div>
  <div style="font-size:12px;color:var(--color-accent-200)">Smoking</div>
</div>'''),
    'quick': (320, 153, f'''
<div class="w" style="width:320px;height:153px;box-sizing:border-box;padding:16px 18px;display:flex;flex-direction:column">
  <div style="display:flex;align-items:flex-start;gap:12px">
    <div style="flex:1">
      <div style="display:flex;align-items:center;gap:6px;font-size:12px;color:var(--color-neutral-400)"><i class="ph ph-cookie" style="color:var(--color-accent-300);font-size:14px"></i>Sugar · since last slip</div>
      <div style="font-size:32px;font-weight:500;letter-spacing:-0.03em;line-height:1.2;font-variant-numeric:tabular-nums;margin-top:4px">13h 12m</div>
    </div>
    <div style="width:52px;height:52px;box-sizing:border-box;border-radius:26px;border:1px solid var(--color-accent);color:var(--color-accent-300);font-size:20px;display:flex;align-items:center;justify-content:center"><i class="ph ph-hand-palm"></i></div>
  </div>
  <div style="flex:1"></div>
  <div style="height:6px;border-radius:3px;background:var(--color-neutral-800)"><div style="height:100%;border-radius:3px;background:var(--color-accent);width:44%"></div></div>
  <div style="display:flex;justify-content:space-between;margin-top:7px;font-size:11.5px"><span style="color:{FAIL}">16h 47m left or it's a fail</span><span style="color:var(--color-neutral-500)">Best 1d 6h</span></div>
</div>'''),
}

rows = [('ph-cigarette', 'Smoking', '3h 54m', 98, '5m 54s to go', FAIL),
        ('ph-device-mobile', 'Doomscrolling', '7h 48m', 100, 'Beaten ✓', 'var(--color-accent-300)'),
        ('ph-cookie', 'Sugar', '13h 12m', 44, '16h 47m to go', FAIL),
        ('ph-moon', 'Late-night snacks', '2d 2h', 100, 'Beaten ✓', 'var(--color-accent-300)')]
row_html = ''.join(f'''
  <div style="display:flex;align-items:center;gap:10px;padding:9px 0">
    <div style="flex:1;min-width:0">
      <div style="display:flex;align-items:baseline;justify-content:space-between;gap:8px">
        <span style="display:flex;align-items:center;gap:6px;font-size:13px;white-space:nowrap;overflow:hidden"><i class="ph {ic}" style="color:var(--color-accent-300)"></i>{name}</span>
        <span style="font-size:15px;font-weight:500;font-variant-numeric:tabular-nums">{t}</span>
      </div>
      <div style="height:4px;border-radius:2px;background:var(--color-neutral-800);margin-top:7px"><div style="height:100%;border-radius:2px;background:var(--color-accent);width:{pct}%"></div></div>
      <div style="font-size:11px;color:{col};margin-top:5px">{st}</div>
    </div>
    <div style="width:36px;height:36px;box-sizing:border-box;flex:none;border-radius:18px;border:1px solid var(--color-neutral-700);color:var(--color-neutral-300);display:flex;align-items:center;justify-content:center;font-size:15px"><i class="ph ph-hand-palm"></i></div>
  </div>''' for ic, name, t, pct, st, col in rows)
pages['list'] = (320, 358, f'''
<div class="w" style="width:320px;box-sizing:border-box;padding:18px 18px 12px">
  <div style="display:flex;align-items:baseline;justify-content:space-between;margin-bottom:8px"><span style="font-size:15px;font-weight:500">Intervals</span><span style="font-size:12px;color:var(--color-accent-300)">2/4 beaten</span></div>
  {row_html}
</div>''')

out.mkdir(parents=True, exist_ok=True)
for k, (w, h, body) in pages.items():
    (out / f'{k}.html').write_text(head + body + '</body></html>', encoding='utf-8')
    print(k, w, h)
