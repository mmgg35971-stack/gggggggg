// يبني preview للواجهة (ثيم الهالوين: Dark Enchanted Night) كـ HTML + صور PNG، بنفس المقاسات والألوان اللي بالكود.
//   node tools/preview.js        -> docs/preview/preview.html + desktop.png + phone.png
// النصوص بتبويب Prince AI حقيقية: يشغّل عقل Prince AI على سيناريو (علكان يروح ويرجع).
// تقريبي: الخطوط مو نفس خطوط Roblox بالضبط (Code ~ Inconsolata، Fantasy ~ Fondamento).
const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

const ROOT = path.join(__dirname, '..');
const OUT = path.join(ROOT, 'docs', 'preview');
fs.mkdirSync(OUT, { recursive: true });

// ---------- 1) نصوص حقيقية من عقل Prince AI ----------
function brainTexts() {
  const core = fs.readFileSync(path.join(ROOT, 'src', 'newtabs', '23_ai_core.lua'), 'utf8');
  const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
  const code = core + `
local b = PrinceAICore.newBrain()
for t = 1, 40 do
  b:tick({ t = t, hp = 1000, maxHp = 1000, alive = true, pos = { x = (t % 2) * 30, y = 100, z = 0 }, vy = 0,
    fps = 58, ping = 95, farms = { "ImpelTest" }, progress = { kills = 3 }, serverAge = 1800, placeKind = "dungeon",
    toolEquipped = true, status = "Floor 2 - stage 3" })
end
local function esc(s) return (tostring(s):gsub("\\\\", "\\\\\\\\"):gsub('"', '\\\\"'):gsub("\\n", "\\\\n")) end
local ex = {}
for _, l in ipairs(b:explain(12)) do ex[#ex + 1] = '"' .. esc(l) .. '"' end
return '{"summary":"' .. esc(b:summary()) .. '","plan":"' .. esc(b:planText()) .. '","budget":"' .. b:budgetLeft() .. ' / ' .. b.autoBudget
  .. '","explain":[' .. table.concat(ex, ",") .. '],"answer":"' .. esc(b:answer("why stuck?")) .. '"}'`;
  if (lauxlib.luaL_loadstring(L, to_luastring(code)) !== 0 || lua.lua_pcall(L, 0, 1, 0) !== 0) {
    throw new Error(lua.lua_tojsstring(L, -1));
  }
  return JSON.parse(lua.lua_tojsstring(L, -1));
}
const ai = brainTexts();

// ---------- 2) HTML ----------
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const E = {
  label: (t, wrap, cls) => `<div class="lbl${wrap ? ' wrap' : ''}${cls ? ' ' + cls : ''}">${esc(t).replace(/\n/g, '<br>')}</div>`,
  toggle: (t, on) => `<div class="tgl"><span class="box${on ? ' on' : ''}"></span>${esc(t)}</div>`,
  dropdown: (t, v) => `<div class="lbl">${esc(t)}</div><div class="dd"><span>${esc(v)}</span><span class="arrow">▼</span></div>`,
  slider: (t, v, min, max) => `<div class="lbl">${esc(t)}</div><div class="sld"><div class="fill" style="width:${((v - min) / (max - min)) * 100}%"></div><span>${v}/${max}</span></div>`,
  button: (t) => `<div class="btn">${esc(t)}</div>`,
  input: (t, ph) => `<div class="lbl">${esc(t)}</div><div class="inp">${esc(ph)}</div>`,
};
const box = (title, items) => `<div class="gb"><div class="hl"></div><div class="gbt">${esc(title)}</div><div class="gbc">${items.join('')}</div></div>`;
// القرع المرسوم: نفس أجزاء HW.pumpkin (جسم بتدرج، ضلعين، عنق، عيون معينات، فم)
const pumpkin = (size) => `<span class="pk" style="width:${size}px;height:${size}px"><span class="pk-stem"></span><span class="pk-body"><i class="rib a"></i><i class="rib b"></i>${size >= 14 ? '<i class="eye a"></i><i class="eye b"></i><i class="mouth"></i>' : ''}</span></span>`;

const left = [
  box('Prince AI', [
    E.label('Logic engine: watches the game,', true, 'sec'), E.label('finds the problem and why, then fixes it.', true, 'sec'),
    E.toggle('AI analysis', true), E.dropdown('Mode', 'Advise'), E.dropdown('Language', 'EN'),
    E.toggle('Notifications', true), E.slider('Sure enough at (%)', 55, 30, 90),
  ]),
  box('Analysis', [
    E.label('State: ' + ai.summary, true, 'state'), E.label('Plan: ' + ai.plan, true), E.label('Auto fixes left: ' + ai.budget + '  | mode Advise', false, 'sec'),
    E.button('Apply suggestion'), E.button('Copy analysis'),
  ]),
];
const right = [
  box('Thinking tree (why)', [E.label(ai.explain.join('\n'), true)]),
  box('Ask the AI', [
    E.label('why / cause / plan / tree / history', true, 'sec'), E.label('advice / errors / progress / fps / learn', true, 'sec'),
    E.input('Question', 'why stuck?'), E.label(ai.answer, true), E.button('Forget what it learned'),
  ]),
];

const TABS = ['Main', 'Fish', 'Misc', 'ESP', 'Dungeon', 'Farm', 'Kaitun', 'Cupid', 'Waves', 'Impel', 'Impel Down Zyph', 'Auto Impel (test)', 'Prince AI', 'Config'];
const embers = [[12, 78, 3, 0.55], [27, 64, 2, 0.4], [46, 84, 3, 0.35], [61, 58, 2, 0.5], [83, 72, 3, 0.3], [91, 88, 2, 0.45]]
  .map(([x, y, sz, op]) => `<span class="em" style="left:${x}%;top:${y}%;width:${sz}px;height:${sz}px;opacity:${op}"></span>`).join('');

const windowHtml = `
<div class="shadow"></div>
<div class="win" id="win">
  <div class="bg">
    <span class="glow p1"></span><span class="glow p2"></span><span class="glow o1"></span>
    <span class="halo"></span><span class="moon"><i class="cr a"></i><i class="cr b"></i></span>
    <span class="cloud c1"></span><span class="cloud c2"></span>
    <span class="fog f1"></span><span class="fog f2"></span>${embers}
  </div>
  <div class="head">${pumpkin(16)}<span class="title">PRINCE HUB</span></div>
  <div class="profile"><span class="av">P</span><span class="pname">Prince</span><span class="pill">LV 420</span></div>
  <div class="close">X</div>
  <div class="msi">
    <div class="arrowbtn" style="left:8px">&lt;</div>
    <div class="tabbar"><div class="tabs" id="tabs">${TABS.map((t) => `<div class="tab${t === 'Prince AI' ? ' sel' : ''}"><span>${esc(t)}</span><i class="bar"></i></div>`).join('')}</div></div>
    <div class="arrowbtn" style="right:8px">&gt;</div>
    <div class="cont"><div class="side l">${left.join('')}</div><div class="side r">${right.join('')}</div></div>
  </div>
</div>`;

const statsHtml = `
<div class="stats">
  <div class="stop">${pumpkin(14)}<span class="stt">Prince Stats</span><span class="sb">-</span><span class="sb">X</span></div>
  <div class="srow h">Auto Impel (test)</div>
  ${[['State', 'Floor 2 - stage 3'], ['Where', 'Dungeon - 2'], ['Stage', '3'], ['Target', 'Kelvin'], ['Kills', '17'], ['Health', 'OK (0 err/60s)']]
    .map(([k, v]) => `<div class="srow"><b>${k}</b>: ${esc(v)}</div>`).join('')}
</div>`;
const toastHtml = `<div class="toast"><i></i>[AI] Stuck in place -> Jump + lift 25 studs</div>`;

const html = `<!doctype html><html><head><meta charset="utf-8"><title>Prince Hub preview</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inconsolata:wght@400;700&family=Fondamento&family=Montserrat:wght@500;700&display=swap">
<style>
:root{--bg:#0B0A10;--bg2:#15131D;--surface:#211A2B;--raised:#2C2038;--line:#3A2D4A;--primary:#FF7518;--ember:#FF9A3D;--purple:#8B5CF6;
 --lavender:#C4A7FF;--text:#F5F0FA;--text2:#B5ADBF;--muted:#827A8B;--success:#75D6A1;--warning:#F2C66D;--danger:#F06A75;--moon:#F3E9D2}
*{box-sizing:border-box;margin:0;padding:0}
body{width:100vw;height:100vh;overflow:hidden;font-family:Inconsolata,monospace;color:var(--text);
 background:radial-gradient(ellipse at 70% 20%,#2c3e3a 0,#18222a 45%,#0b0f14 100%)}
.scene{position:absolute;inset:0}
.scene:after{content:'';position:absolute;left:0;right:0;bottom:0;height:28%;background:linear-gradient(#1d2b22,#121a14);opacity:.9}
.hint{position:absolute;left:12px;bottom:10px;z-index:5;font:500 12px Montserrat,sans-serif;color:#9fb0b8;opacity:.8}
.stage{position:absolute;left:50%;top:50%;width:640px;height:600px;transform-origin:center;z-index:3}
.shadow{position:absolute;inset:4px -4px -8px -4px;border-radius:16px;background:rgba(0,0,0,.45);filter:blur(6px)}
.win{position:absolute;inset:0;border-radius:12px;overflow:hidden;border:1px solid var(--line);box-shadow:inset 0 1px 0 rgba(196,167,255,.45)}
.bg{position:absolute;inset:0;background:linear-gradient(180deg,var(--bg),var(--bg2));overflow:hidden}
.glow{position:absolute;border-radius:50%}
.glow.p1{width:350px;height:350px;left:-175px;bottom:-175px;background:radial-gradient(circle,rgba(139,92,246,.16),rgba(139,92,246,0) 70%)}
.glow.p2{width:240px;height:240px;left:-120px;bottom:-120px;background:radial-gradient(circle,rgba(139,92,246,.12),rgba(139,92,246,0) 70%)}
.glow.o1{width:300px;height:300px;right:-80px;top:-140px;background:radial-gradient(circle,rgba(255,154,61,.10),rgba(255,154,61,0) 70%)}
.moon{position:absolute;width:150px;height:150px;right:40px;top:-64px;border-radius:50%;background:rgba(243,233,210,.14)}
.halo{position:absolute;width:200px;height:200px;right:15px;top:-89px;border-radius:50%;background:rgba(196,167,255,.035)}
.cr{position:absolute;border-radius:50%;background:rgba(21,19,29,.09)}.cr.a{width:26px;height:26px;left:38px;top:72px}.cr.b{width:16px;height:16px;left:92px;top:98px}
.cloud{position:absolute;border-radius:99px;background:var(--bg2)}
.cloud.c1{width:170px;height:22px;right:80px;top:46px;opacity:.65}.cloud.c2{width:120px;height:16px;right:20px;top:22px;opacity:.55}
.fog{position:absolute;left:-30%;width:160%;background:linear-gradient(180deg,rgba(196,167,255,0),rgba(196,167,255,.08))}
.fog.f1{height:90px;bottom:0}.fog.f2{height:110px;bottom:0;left:-55%;opacity:.8}
.em{position:absolute;border-radius:50%;background:var(--ember)}
.head{position:absolute;left:9px;top:4px;height:18px;display:flex;align-items:center;gap:5px;z-index:2}
.title{font:18px Fondamento,serif;color:var(--primary);line-height:18px;margin-top:1px}
.pk{position:relative;display:inline-block;flex:none}
.pk-body{position:absolute;left:0;right:0;bottom:0;height:80%;border-radius:50%;background:linear-gradient(180deg,var(--ember),#C2410C)}
.pk-stem{position:absolute;left:50%;top:0;width:14%;height:26%;min-width:2px;background:#5B7F3A;border-radius:3px;transform:translateX(-30%) rotate(12deg);z-index:1}
.rib{position:absolute;top:10%;height:80%;width:8%;min-width:1px;border-radius:9px;background:rgba(194,65,12,.45)}.rib.a{left:27%}.rib.b{left:65%}
.eye{position:absolute;width:16%;height:20%;top:32%;background:#FFD27A;transform:rotate(45deg)}.eye.a{left:24%}.eye.b{left:60%}
.mouth{position:absolute;left:27%;width:46%;height:12%;top:64%;border-radius:9px;background:#FFD27A}
.profile{position:absolute;right:34px;top:3px;height:19px;display:flex;align-items:center;gap:6px;z-index:2;font:500 12px Montserrat,sans-serif}
.av{width:18px;height:18px;border-radius:50%;background:var(--raised);border:1px solid rgba(139,92,246,.7);color:var(--lavender);font:700 11px Montserrat;display:flex;align-items:center;justify-content:center}
.pname{color:var(--text2)}
.pill{height:16px;line-height:16px;padding:0 7px;border-radius:99px;background:var(--raised);color:var(--ember);font:700 11px Montserrat}
.close{position:absolute;right:5px;top:3px;width:20px;height:20px;border-radius:4px;color:var(--text2);font:700 13px Montserrat,sans-serif;text-align:center;line-height:20px;z-index:2}
.msi{position:absolute;left:8px;top:25px;right:8px;bottom:8px}
.tabbar{position:absolute;left:24px;right:24px;top:8px;height:22px;overflow:hidden}
.tabs{display:flex;gap:8px;position:absolute;right:0;top:0}
.tab{position:relative;height:21px;padding:0 6px;line-height:21px;font-size:14px;white-space:nowrap;background:rgba(33,26,43,.65);border-radius:6px;color:var(--text2)}
.tab.sel{background:var(--raised);color:var(--primary)}
.tab .bar{display:none;position:absolute;left:20%;right:20%;bottom:0;height:2px;border-radius:2px;background:var(--primary)}
.tab.sel .bar{display:block}
.arrowbtn{position:absolute;top:8px;width:14px;height:21px;line-height:20px;text-align:center;font-size:14px;color:var(--text2);background:rgba(33,26,43,.65);border-radius:6px}
.cont{position:absolute;left:0;right:0;top:30px;bottom:0;border-radius:12px;background:rgba(21,19,29,.88);border:1px solid rgba(58,45,74,.8);overflow:hidden}
.side{position:absolute;top:7px;width:calc(50% - 10px);display:flex;flex-direction:column;gap:8px}
.side.l{left:7px}.side.r{left:calc(50% + 5px)}
.gb{position:relative;background:var(--surface);border:1px solid rgba(58,45,74,.9);border-radius:8px;padding:0 4px 6px;overflow:hidden}
.hl{position:absolute;left:8px;width:18px;top:0;height:2px;border-radius:2px;background:var(--lavender)}
.gbt{height:20px;line-height:22px;font:700 13px Montserrat,sans-serif;color:var(--lavender)}
.gbc{display:flex;flex-direction:column;gap:5px;padding-right:4px}
.lbl{font-size:14px;line-height:15px;white-space:nowrap;overflow:hidden}
.lbl.wrap{white-space:normal;word-break:break-word}
.lbl.sec{color:var(--text)}
.lbl.state{color:var(--ember)}
.tgl{display:flex;align-items:center;gap:6px;font-size:14px;height:15px}
.tgl .box{width:13px;height:13px;background:var(--raised);border:1px solid var(--line);outline:1px solid #000}
.tgl .box.on{background:var(--primary);border-color:#b3570e}
.dd,.inp,.btn{height:20px;line-height:18px;font-size:14px;background:var(--raised);border:1px solid var(--line);outline:1px solid #000;padding:0 5px}
.dd{display:flex;justify-content:space-between}.dd .arrow{font-size:9px;opacity:.8}
.inp{color:var(--muted)}
.btn{text-align:center}
.sld{position:relative;height:13px;background:var(--raised);border:1px solid var(--line);outline:1px solid #000;font-size:13px;line-height:11px;text-align:center}
.sld .fill{position:absolute;left:0;top:0;bottom:0;background:var(--primary)}
.sld span{position:relative;text-shadow:0 0 2px #000,0 0 2px #000}
.stats{position:absolute;left:20px;top:140px;width:230px;border-radius:8px;background:var(--surface);border:1px solid var(--line);overflow:hidden;z-index:4;padding-bottom:4px}
.stop{height:24px;display:flex;align-items:center;gap:6px;padding:0 4px 0 8px;background:var(--raised)}
.stt{flex:1;font:700 13px Montserrat,sans-serif;color:var(--lavender)}
.sb{width:20px;height:18px;line-height:18px;text-align:center;background:var(--surface);color:var(--text2);border-radius:4px;font-size:14px}
.srow{font-size:13px;height:16px;line-height:16px;padding:0 8px}.srow.h{color:var(--ember);font-weight:700;margin-top:3px}
.toast{position:absolute;left:0;top:40px;height:21px;line-height:21px;padding:0 10px 0 9px;font-size:14px;z-index:6;border-radius:6px;
 background:linear-gradient(90deg,#1f1729,var(--raised));border:1px solid var(--line)}
.toast i{position:absolute;left:-1px;top:-1px;bottom:-1px;width:3px;border-radius:6px 0 0 6px;background:var(--primary)}
.mini{position:absolute;width:46px;height:46px;border-radius:50%;background:rgba(33,26,43,.92);border:1.5px solid var(--line);z-index:4;
 box-shadow:0 0 0 5px rgba(255,154,61,.16);display:flex;align-items:center;justify-content:center}
.minicap{position:absolute;font:500 11px Montserrat,sans-serif;color:#cfd8dc;z-index:4;text-align:center;width:120px}
</style></head><body>
<div class="scene"></div>
<div class="stage" id="stage">${windowHtml}</div>
${statsHtml}
${toastHtml}
<div class="mini" id="mini">${pumpkin(30)}</div><div class="minicap" id="minicap">when the menu is hidden</div>
<div class="hint">Prince Hub v21 preview - Dark Enchanted Night (approximate: fonts differ a little from Roblox)</div>
<script>
// نفس حساب PN_fitScale: min((W-10)/640, (H-50)/600) بين 0.3 و 1
const W = innerWidth, H = innerHeight;
const s = Math.max(0.3, Math.min(1, Math.min((W - 10) / 640, (H - 50) / 600)));
const st = document.getElementById('stage');
st.style.transform = 'translate(-50%,-50%) scale(' + s + ')';
const stats = document.querySelector('.stats');
const mini = document.getElementById('mini'), cap = document.getElementById('minicap');
if (W < 900) {
  // مثل 22_ui_scale.lua: نافذة الـ stats تصغر بنفس النسبة بس مو أقل من 0.7
  stats.style.transform = 'scale(' + Math.min(1, Math.max(0.7, s)) + ')'; stats.style.transformOrigin = 'top left';
  stats.style.top = '72px'; stats.style.left = '8px';
  mini.style.left = (W - 64) + 'px'; mini.style.top = (H - 92) + 'px'; cap.style.left = (W - 126) + 'px'; cap.style.top = (H - 40) + 'px';
  document.querySelector('.hint').style.fontSize = '9px';
  // مثل PrinceApplyScale بـ 07_Hub.lua: كل ابن للـ ScreenGui يصغر بنفس النسبة (الإشعارات هم)،
  // والزر المصغر مو أقل من 0.8 حتى ينضغط بسهولة
  const toast = document.querySelector('.toast'); toast.style.transform = 'scale(' + s + ')'; toast.style.transformOrigin = 'top left';
  mini.style.transform = 'scale(' + Math.max(s, 0.8) + ')';
  // مثل 22_ui_scale.lua: زر X يكبر حتى يبقى 80% من حجمه الطبيعي
  const x = document.querySelector('.close'); x.style.transform = 'scale(' + Math.max(1, 0.8 / s) + ')'; x.style.transformOrigin = 'top right';
} else {
  mini.style.left = (W - 120) + 'px'; mini.style.top = (H - 120) + 'px'; cap.style.left = (W - 157) + 'px'; cap.style.top = (H - 68) + 'px';
}
</script></body></html>`;
fs.writeFileSync(path.join(OUT, 'preview.html'), html);

// ---------- 3) صور ----------
(async () => {
  let chromium;
  try { ({ chromium } = require('playwright')); } catch (e) { console.log('playwright not found: only HTML written'); return; }
  const browser = await chromium.launch();
  const shots = [
    { name: 'desktop.png', viewport: { width: 1280, height: 720 } },
    { name: 'phone.png', viewport: { width: 800, height: 360 } }, // هاتف بالعرض (landscape)
  ];
  for (const s of shots) {
    const page = await browser.newPage({ viewport: s.viewport, deviceScaleFactor: 2 });
    await page.goto('file://' + path.join(OUT, 'preview.html'));
    await page.waitForLoadState('networkidle').catch(() => {});
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: path.join(OUT, s.name) });
    await page.close();
    console.log('wrote docs/preview/' + s.name);
  }
  await browser.close();
})();
