"""Builds the Play Console graphics for Orbix into mobile/store/play/.
Feature graphic 1024x500, phone screenshots 1080x1920 (illustrated screens, no prices: the Play build sells nothing)."""
import asyncio, base64, pathlib
from playwright.async_api import async_playwright

ROOT = pathlib.Path(__file__).resolve().parent.parent / "mobile" / "store"
OUT = ROOT / "play"
ICON = "data:image/png;base64," + base64.b64encode((ROOT / "play_icon_512.png").read_bytes()).decode()

CSS = """
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'Poppins',sans-serif;color:#fff;background:#0A0A14;-webkit-font-smoothing:antialiased}
.grad{background:linear-gradient(135deg,#6A5CFF,#9B5CFF 55%,#FF5CA8)}
.gtext{background:linear-gradient(90deg,#8F7BFF,#FF7CBB);-webkit-background-clip:text;color:transparent}
"""

# ---------- phone UI pieces (logical size 480 x 760, drawn at 2x) ----------
UI_CSS = """
.ui{width:480px;height:760px;background:#0A0A14;position:relative;overflow:hidden;font-size:14px}
.sb{height:28px;display:flex;justify-content:space-between;padding:8px 18px 0;font-size:11px;color:#cfcfe6}
.h1{font-size:24px;font-weight:700;padding:10px 16px 8px}
.nav{position:absolute;left:0;right:0;bottom:0;height:64px;background:#13131F;border-top:1px solid #24243A;display:flex;justify-content:space-around;align-items:center}
.nav div{display:flex;flex-direction:column;align-items:center;font-size:10px;color:#9A9AB5;gap:3px;width:70px;padding:6px 0;border-radius:18px}
.nav div.on{background:#7C5CFF;color:#fff}
.nav i{width:20px;height:20px;border:2px solid currentColor;border-radius:6px;display:block}
.card{background:#13131F;border:1px solid #24243A;border-radius:16px}
.thumb{aspect-ratio:16/9;border-radius:14px;position:relative;overflow:hidden}
.dur{position:absolute;right:8px;bottom:8px;background:#000b;border-radius:6px;padding:1px 6px;font-size:10px;font-weight:600}
.prem{position:absolute;left:8px;top:8px;background:#000a;border-radius:8px;padding:2px 8px;font-size:10px;font-weight:600;color:#FFC94D}
.av{width:36px;height:36px;border-radius:11px;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:15px;flex:none}
.muted{color:#9A9AB5}
.btn{background:#7C5CFF;border-radius:12px;padding:8px 16px;font-weight:600;font-size:13px}
.btn.o{background:none;border:1px solid #24243A}
.pill{display:inline-block;background:#24243A;border-radius:10px;padding:2px 9px;font-size:11px;color:#cfcfe6}
.bar{height:6px;border-radius:3px;background:#24243A;overflow:hidden}.bar b{display:block;height:100%}
.row{display:flex;align-items:center;gap:10px}
"""

GR = ["linear-gradient(135deg,#3b2a8c,#7c5cff)", "linear-gradient(135deg,#8c2a6a,#ff5ca8)", "linear-gradient(135deg,#1f6f8c,#5cd0ff)",
      "linear-gradient(135deg,#8c5a1f,#ffc94d)", "linear-gradient(135deg,#1f8c5a,#5cffb0)", "linear-gradient(135deg,#4a2a8c,#c45cff)"]
AV = ["linear-gradient(135deg,#6A5CFF,#FF5CA8)"]

def nav(on):
    items = ["Cloud", "Home", "Explore", "Channel", "Profile"]
    return '<div class="nav">' + "".join(f'<div class="{"on" if n==on else ""}"><i></i>{n}</div>' for n in items) + "</div>"

def sb(): return '<div class="sb"><span>9:41</span><span>5G ▮▮▮ 92%</span></div>'

def vcard(i, title, ch, dur, prem=False):
    return f'''<div style="padding:6px 16px 10px"><div class="thumb" style="background:{GR[i%6]}"><div class="dur">{dur}</div>{'<div class="prem">★ Premium</div>' if prem else ''}
    <div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-size:40px;opacity:.55">▶</div></div>
    <div class="row" style="margin-top:8px;align-items:flex-start"><div class="av" style="background:{AV[0]}">{ch[0]}</div><div><div style="font-weight:600;font-size:14px;line-height:1.3">{title}</div><div class="muted" style="font-size:11px;margin-top:2px">{ch}</div></div></div></div>'''

def scene_home():
    tiles = "".join(f'<div style="width:78px;text-align:center"><div class="av" style="width:68px;height:68px;border-radius:18px;font-size:26px;background:#13131F;border:1px solid #24243A;color:#7C5CFF;margin:0 auto">{n[0]}</div><div class="muted" style="font-size:11px;margin-top:4px;white-space:nowrap">{n}</div></div>' for n in ["Daily Tech","Study Hub","Fit Life","Music Room","Travel Diaries"])
    posts = "".join(f'<div><div class="thumb" style="aspect-ratio:.62;background:{GR[i]}"></div><div style="font-size:11px;margin-top:4px;font-weight:500">{t}</div></div>' for i,t in enumerate(["Morning routine","Python basics","Trail run","Lo-fi mix","Goa in 3 days","Desk setup"]))
    return f'''{sb()}<div class="row" style="padding:10px 16px"><div style="flex:1;font-size:22px;font-weight:700"><span class="gtext">Orbix</span></div><div class="av" style="width:32px;height:32px;background:#24243A;font-size:13px">U</div></div>
    <div class="card" style="margin:0 16px;padding:14px;background:linear-gradient(135deg,#2a2160,#4b2a7a)"><div style="font-weight:600;font-size:15px">15 GB free cloud storage</div><div class="muted" style="font-size:12px;margin:3px 0 10px">Keep photos, videos and files private.</div><div class="bar"><b class="grad" style="width:18%"></b></div></div>
    <div class="row" style="padding:14px 16px 6px"><div style="flex:1;font-size:17px;font-weight:600">Channels</div><div style="color:#FF5CA8;font-size:13px">See all</div></div>
    <div class="row" style="padding:0 16px;gap:12px;overflow:hidden">{tiles}</div>
    <div style="font-size:17px;font-weight:600;padding:14px 16px 8px">New shows</div>
    <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:10px;padding:0 16px">{posts}</div>{nav("Home")}'''

def scene_explore():
    chips = "".join(f'<span class="pill" style="{"background:#7C5CFF;color:#fff" if i==0 else ""}">{c}</span>' for i,c in enumerate(["All","Movies","Music","Education","Gaming","Tech"]))
    return f'''{sb()}<div class="h1">Explore</div>
    <div class="card" style="margin:0 16px 10px;padding:11px 14px;border-radius:14px" ><span class="muted">⌕  Search videos</span></div>
    <div class="row" style="padding:0 16px 8px;gap:6px;overflow:hidden">{chips}</div>
    {vcard(0,"Learn Python in 20 minutes","Study Hub","20:14")}{vcard(1,"Sunrise trail run, behind the scenes","Fit Life","8:02",True)}{nav("Explore")}'''

def scene_channel():
    return f'''{sb()}<div class="row" style="padding:8px 8px"><span style="font-size:22px;padding:0 8px">←</span><div style="font-size:18px;font-weight:600">Study Hub</div></div>
    <div class="card" style="margin:4px 16px 10px;padding:14px"><div class="row" style="align-items:flex-start"><div class="av" style="width:52px;height:52px;border-radius:16px;font-size:22px;background:{AV[0]}">S</div>
    <div style="flex:1"><div style="font-weight:600;font-size:16px">Study Hub</div><div class="muted" style="font-size:12px">12.4K members</div><div class="muted" style="font-size:12px;margin-top:6px;line-height:1.4">Short lessons on coding, maths and exam prep.</div></div><div class="btn" style="padding:7px 18px">Join</div></div></div>
    {vcard(2,"Algebra in 10 minutes","Study Hub","10:03")}{vcard(4,"How to learn faster (full guide)","Study Hub","14:40",True)}{nav("Channel")}'''

def scene_cloud():
    files = [("Holiday-2026.mp4","248 MB","▶",2),("Resume.pdf","1.2 MB","▤",0),("Photos backup","1.8 GB","▣",4),("Notes.txt","12 KB","≡",3)]
    rows = "".join(f'<div class="card row" style="margin:0 16px 8px;padding:10px 12px"><div class="av" style="background:{GR[g]};font-size:16px">{ic}</div><div style="flex:1"><div style="font-weight:500;font-size:14px">{n}</div><div class="muted" style="font-size:11px">{s}</div></div><span class="muted">⋮</span></div>' for n,s,ic,g in files)
    return f'''{sb()}<div class="h1">Cloud</div>
    <div class="card" style="margin:0 16px 14px;padding:16px"><div class="row"><div style="flex:1"><div class="muted" style="font-size:12px">Storage used</div><div style="font-size:26px;font-weight:700">2.3 GB <span class="muted" style="font-size:14px;font-weight:400">of 15 GB</span></div></div><div style="width:64px;height:64px;border-radius:50%;background:conic-gradient(#9B5CFF 0 15%,#24243A 0);display:flex;align-items:center;justify-content:center"><div style="width:48px;height:48px;border-radius:50%;background:#13131F;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:600">15%</div></div></div></div>
    <div style="font-size:15px;font-weight:600;padding:0 16px 8px">Your files</div>{rows}
    <div class="btn grad" style="position:absolute;right:18px;bottom:80px;border-radius:16px;padding:12px 20px;background:#7C5CFF">⇪ Upload</div>{nav("Cloud")}'''

def scene_player():
    return f'''<div style="position:absolute;inset:0;background:linear-gradient(160deg,#241b52,#0b0b16 55%,#3a1a4a)"></div>
    <div style="position:absolute;top:150px;left:0;right:0;text-align:center;font-size:90px;opacity:.14">▶</div>
    <div style="position:absolute;left:0;right:0;top:0;padding:14px 12px;display:flex;gap:10px;align-items:center;background:linear-gradient(#000a,transparent)"><span style="font-size:22px">←</span><div style="font-weight:600;flex:1">Sunrise trail run</div><span>🔓</span></div>
    <div style="position:absolute;left:0;right:0;top:300px;display:flex;justify-content:center;align-items:center;gap:26px;font-size:34px"><span>⟲</span><div style="width:78px;height:78px;border-radius:50%;background:#000a;display:flex;align-items:center;justify-content:center;font-size:36px">❚❚</div><span>⟳</span></div>
    <div style="position:absolute;left:0;right:0;bottom:0;padding:0 14px 16px;background:linear-gradient(transparent,#000d)"><div class="row" style="font-size:12px"><span style="flex:1">3:42 / 8:02</span><span>1.25x</span><span style="font-size:18px">⛶</span></div><div class="bar" style="margin-top:8px;height:5px"><b style="width:46%;background:#7C5CFF"></b></div></div>
    <div style="position:absolute;left:50%;top:480px;transform:translateX(-50%);background:#000c;border-radius:14px;padding:12px 18px;text-align:center;font-weight:600"><div style="font-size:24px">⏩</div>+24 s<div class="muted" style="font-weight:400;font-size:12px">4:06</div></div>'''

def scene_safety():
    rows = [("Report content","Tell us about anything that breaks the rules"),("Block channel","Stop seeing a channel's posts"),("Community guidelines","What is and isn't allowed"),("Delete account","Remove your account and files, any time")]
    return f'''{sb()}<div class="h1">Profile</div>
    <div class="card row" style="margin:0 16px 14px;padding:14px"><div class="av" style="width:50px;height:50px;border-radius:15px;font-size:20px;background:{AV[0]}">A</div><div><div style="font-weight:600">Aarav</div><div class="muted" style="font-size:12px">Free account · 15 GB</div></div></div>
    <div style="font-size:12px;padding:0 18px 8px" class="muted">SAFETY & PRIVACY</div>
    {"".join(f'<div class="card" style="margin:0 16px 8px;padding:14px"><div style="font-weight:600;font-size:14px">{a}</div><div class="muted" style="font-size:12px;margin-top:2px">{b}</div></div>' for a,b in rows)}
    <div class="card row" style="margin:12px 16px;padding:12px;background:#13131F"><span style="font-size:20px">🔒</span><div class="muted" style="font-size:12px;line-height:1.4">Your files open through short-lived secure links. Only you can see them.</div></div>{nav("Profile")}'''

SHOTS = [
    ("01_home", "Cloud storage and<br>channels in one app", scene_home),
    ("02_explore", "Discover videos<br>from creators", scene_explore),
    ("03_player", "A video player that<br>feels natural", scene_player),
    ("04_channels", "Follow channels<br>you like", scene_channel),
    ("05_cloud", "15 GB free,<br>private cloud", scene_cloud),
    ("06_safety", "Safety tools<br>built into the app", scene_safety),
]

def shot_html(title, scene):
    return f'''<!doctype html><meta charset=utf-8><style>{CSS}{UI_CSS}
    body{{width:1080px;height:1920px;position:relative;overflow:hidden;background:radial-gradient(circle at 20% 0%,#2a1f66 0,#0A0A14 55%),#0A0A14}}
    .cap{{position:absolute;top:110px;left:0;right:0;text-align:center;font-size:70px;font-weight:700;line-height:1.18;letter-spacing:-1px}}
    .glow{{position:absolute;width:900px;height:900px;border-radius:50%;background:#7C5CFF;filter:blur(160px);opacity:.28;left:-200px;top:900px}}
    .dev{{position:absolute;left:60px;top:370px;width:960px;height:1520px;border-radius:70px 70px 0 0;background:#000;padding:14px 14px 0;box-shadow:0 0 0 3px #2c2c44,0 40px 120px #0009;overflow:hidden}}
    .scr{{width:480px;height:760px;transform:scale(2);transform-origin:0 0;border-radius:30px 30px 0 0;overflow:hidden}}
    </style><div class="glow"></div><div class="cap">{title.replace("<br>","<br>")}</div>
    <div class="dev"><div class="scr"><div class="ui">{scene()}</div></div></div>'''

def feature_html():
    return f'''<!doctype html><meta charset=utf-8><style>{CSS}{UI_CSS}
    body{{width:1024px;height:500px;position:relative;overflow:hidden;background:radial-gradient(circle at 15% 20%,#3a2a99 0,#0A0A14 60%)}}
    .glow{{position:absolute;width:520px;height:520px;border-radius:50%;background:#FF5CA8;filter:blur(150px);opacity:.22;right:-120px;bottom:-200px}}
    .logo{{position:absolute;left:64px;top:120px;width:120px;height:120px;border-radius:30px;box-shadow:0 20px 60px #7C5CFF66}}
    h1{{position:absolute;left:64px;top:262px;font-size:60px;line-height:1.05;font-weight:700;letter-spacing:-1px}}
    p{{position:absolute;left:66px;top:352px;font-size:25px;color:#c9c9e4;width:470px;line-height:1.35}}
    .ph{{position:absolute;width:250px;height:410px;border-radius:30px;background:#000;padding:7px;box-shadow:0 0 0 2px #2c2c44,0 30px 80px #000a;overflow:hidden}}
    .ph .scr{{width:480px;height:760px;transform:scale(.5);transform-origin:0 0;border-radius:24px;overflow:hidden}}
    </style><div class="glow"></div>
    <img class="logo" src="{ICON}"><h1>Orbix</h1><p>Private cloud storage and creator channels.</p>
    <div class="ph" style="left:590px;top:70px;transform:rotate(-6deg)"><div class="scr"><div class="ui">{scene_home()}</div></div></div>
    <div class="ph" style="left:770px;top:130px;transform:rotate(5deg)"><div class="scr"><div class="ui">{scene_explore()}</div></div></div>'''

async def main():
    OUT.mkdir(parents=True, exist_ok=True)
    async with async_playwright() as p:
        b = await p.chromium.launch()
        for name, title, scene in SHOTS:
            pg = await b.new_page(viewport={"width": 1080, "height": 1920}, device_scale_factor=1)
            await pg.set_content(shot_html(title, scene)); await pg.wait_for_timeout(250)
            await pg.screenshot(path=str(OUT / f"phone_{name}.png")); await pg.close()
        pg = await b.new_page(viewport={"width": 1024, "height": 500}, device_scale_factor=1)
        await pg.set_content(feature_html()); await pg.wait_for_timeout(250)
        await pg.screenshot(path=str(OUT / "feature_graphic_1024x500.png")); await pg.close()
        await b.close()

asyncio.run(main())
