// UI controller. All game logic lives in ./shared (engine, memory, sim);
// this file only renders state and forwards the player's words.
import { BACKGROUNDS, STAT_KEYS, STAT_NAMES, SKILL_KEYS, SKILL_NAMES, LOCATIONS, NPCS, ITEMS, QUESTS } from './shared/world.js';
import { newGame, POINT_BUY, timeInfo, TIME_WORDS, WEATHER, L, npcsAt, attitudeBand, itemName, locName, xpForCharLevel } from './shared/state.js';
import { takeTurn } from './shared/game.js';
import { openingScene, absenceMessages } from './shared/narrator.js';
import { catchUp, placeNpcs } from './shared/sim.js';
import { pushChat } from './shared/memory.js';
import { Minstrel, BALLAD, moodForLocation } from './music.js';
import { t } from './i18n.js';
import { loadSave, writeSave, deleteSave, loadSettings, saveSettings } from './storage.js';

const $ = (s) => document.querySelector(s);
const settings = loadSettings();
const music = new Minstrel();
music.volume = settings.volume; music.enabled = settings.music;
let state = null;
let ai = null; let aiInfo = null;
let busy = false;

// ------------------------------------------------------------ language
function lang() { return settings.lang; }
function applyLang() {
  const l = lang();
  document.documentElement.lang = l; document.documentElement.dir = l === 'ar' ? 'rtl' : 'ltr';
  document.querySelectorAll('[data-i18n]').forEach((el) => { el.textContent = t(el.dataset.i18n, l); });
  document.querySelectorAll('[data-i18n-ph]').forEach((el) => { el.placeholder = t(el.dataset.i18nPh, l); });
  $('#langBtn').textContent = l === 'ar' ? 'English' : 'العربية';
  document.title = t('title', l);
  showBallad();
}
function setLang(l) { settings.lang = l; saveSettings(settings); if (state) state.lang = l; applyLang(); if (state && !$('#game').classList.contains('hidden')) { renderHud(); rerenderLog(); } }

// ------------------------------------------------------------ AI connection
function serverBase() {
  if (settings.serverUrl) return settings.serverUrl.replace(/\/+$/, '');
  const inApp = !!window.Capacitor?.isNativePlatform?.();
  if (!inApp && /^https?:$/.test(location.protocol)) return location.origin;
  return '';
}
async function fetchJson(url, opts = {}, timeoutMs = 45000) {
  const ctl = new AbortController(); const tm = setTimeout(() => ctl.abort(), timeoutMs);
  try {
    const r = await fetch(url, { ...opts, signal: ctl.signal, headers: { 'content-type': 'application/json', ...(settings.appToken ? { 'x-app-token': settings.appToken } : {}), ...(opts.headers || {}) } });
    if (!r.ok) throw new Error('http_' + r.status);
    return await r.json();
  } finally { clearTimeout(tm); }
}
async function connectAi() {
  const base = serverBase(); ai = null; aiInfo = null;
  if (!base) return null;
  try {
    const h = await fetchJson(base + '/api/health', {}, 6000);
    aiInfo = h;
    if (h.ai) ai = {
      interpret: (p) => fetchJson(base + '/api/ai/interpret', { method: 'POST', body: JSON.stringify(p) }, 30000),
      narrate: (p) => fetchJson(base + '/api/ai/narrate', { method: 'POST', body: JSON.stringify(p) }, 60000)
    };
  } catch { aiInfo = null; }
  renderHud();
  return aiInfo;
}

// ------------------------------------------------------------ screens
function show(id) { for (const s of ['title', 'create', 'game']) $('#' + s).classList.toggle('hidden', s !== id); }

function showBallad() {
  const el = $('#ballad'); if (!el) return;
  el.innerHTML = '';
  BALLAD[lang()].forEach((line, i) => { const s = document.createElement('span'); s.textContent = line; s.style.animationDelay = `${1 + i * 2.2}s`; el.appendChild(s); });
}

function toTitle() {
  show('title'); $('#continueBtn').classList.toggle('hidden', !loadSave());
  music.setMood('title');
}

// ------------------------------------------------------------ character creation
const draft = { background: 'farmhand', stats: Object.fromEntries(STAT_KEYS.map((k) => [k, POINT_BUY.base])) };
function pointsLeft() { return POINT_BUY.points - STAT_KEYS.reduce((a, k) => a + draft.stats[k] - POINT_BUY.base, 0); }
function renderCreate() {
  const l = lang();
  const g = $('#bgGrid'); g.innerHTML = '';
  for (const [id, b] of Object.entries(BACKGROUNDS)) {
    const btn = document.createElement('button'); btn.className = 'bg-card'; btn.type = 'button';
    btn.setAttribute('aria-pressed', String(draft.background === id));
    const bonus = Object.entries(b.stats).map(([k, v]) => `${L(STAT_NAMES[k], l)} +${v}`).join(l === 'ar' ? '، ' : ', ');
    const sk = Object.entries(b.skills).map(([k, v]) => `${L(SKILL_NAMES[k], l)} ${v}`).join(l === 'ar' ? '، ' : ', ');
    btn.innerHTML = `<b></b><span></span><br><small></small>`;
    btn.querySelector('b').textContent = L(b.name, l);
    btn.querySelector('span').textContent = L(b.desc, l);
    btn.querySelector('small').textContent = `${bonus} · ${sk} · ${b.gold} ${t('silver', l)}`;
    btn.onclick = () => { draft.background = id; renderCreate(); };
    g.appendChild(btn);
  }
  const sg = $('#statGrid'); sg.innerHTML = '';
  for (const k of STAT_KEYS) {
    const row = document.createElement('div'); row.className = 'stat';
    row.innerHTML = `<label></label><span style="display:flex;align-items:center;gap:6px"><button type="button" aria-label="-">−</button><span class="v"></span><button type="button" aria-label="+">+</button></span>`;
    row.querySelector('label').textContent = L(STAT_NAMES[k], l);
    row.querySelector('.v').textContent = draft.stats[k] + (BACKGROUNDS[draft.background].stats[k] || 0);
    const [minus, plus] = row.querySelectorAll('button');
    minus.disabled = draft.stats[k] <= POINT_BUY.min; plus.disabled = draft.stats[k] >= POINT_BUY.max || pointsLeft() <= 0;
    minus.onclick = () => { draft.stats[k]--; renderCreate(); };
    plus.onclick = () => { if (pointsLeft() > 0) { draft.stats[k]++; renderCreate(); } };
    sg.appendChild(row);
  }
  $('#points').textContent = t('pointsLeft', l, { n: pointsLeft() });
}
function startNew() {
  const name = $('#cName').value.trim();
  if (!name) { $('#cErr').textContent = t('nameRequired', lang()); return; }
  try {
    state = newGame({ name, gender: $('#cGender').value, background: draft.background, stats: { ...draft.stats }, lang: lang() });
  } catch (e) { $('#cErr').textContent = String(e.message || e); return; }
  placeNpcs(state);
  for (const m of openingScene(state, lang())) pushChat(state, m);
  writeSave(state);
  enterGame(true);
}

// ------------------------------------------------------------ game screen
function enterGame(fresh) {
  show('game'); $('#log').innerHTML = '';
  if (!fresh) {
    const away = catchUp(state);
    for (const m of absenceMessages(away, lang())) pushChat(state, m);
    writeSave(state);
  }
  rerenderLog(fresh ? 1 : 0);
  renderHud();
  music.setMood(moodForLocation(LOCATIONS[state.player.location]));
  setTimeout(() => $('#input').focus({ preventScroll: true }), 300);
}

function renderHud() {
  if (!state) return;
  const l = lang(); const p = state.player; const ti = timeInfo(state.time);
  $('#placeName').textContent = locName(p.location, l);
  const dot = `<span class="mode-dot ${ai ? 'ai' : ''}" title="${t(ai ? 'aiOnline' : 'aiOffline', l)}"></span>`;
  $('#placeWhen').innerHTML = dot;
  $('#placeWhen').append(`${t('day', l, { d: ti.day })} · ${String(ti.hour).padStart(2, '0')}:${String(ti.minute).padStart(2, '0')} · ${L(TIME_WORDS[ti.season], l)} · ${L(WEATHER[state.world.weather], l)}`);
  $('#hpBar').style.width = `${Math.max(0, (p.hp / p.maxHp) * 100)}%`;
  $('#gold').textContent = `${p.gold} ⛁`;
  $('#musicBtn').style.opacity = settings.music ? 1 : 0.4;
}

// message rendering with a quill-like reveal
const queue = []; let revealing = null;
function el(tag, cls, text) { const e = document.createElement(tag); if (cls) e.className = cls; if (text !== undefined) e.textContent = text; return e; }
function msgNode(m) {
  const l = lang();
  if (m.role === 'npc') {
    const n = NPCS[m.speaker];
    const wrap = el('div', 'msg npc'); const sig = el('div', 'sigil', n ? L(n.name, l).trim()[0] : '?');
    const sp = el('div', 'speech'); sp.append(el('div', 'who', n ? L(n.name, l) : m.speaker), el('div', 'line'));
    wrap.append(sig, sp); return { node: wrap, target: sp.querySelector('.line'), text: m.text };
  }
  if (m.role === 'player') {
    const wrap = el('div', 'msg player'); const ink = el('div', 'ink', m.text); ink.append(el('span', 'sig', '— ' + state.player.name)); wrap.append(ink);
    return { node: wrap, target: null };
  }
  if (m.role === 'narrator') { const d = el('div', 'msg narrator parchment'); return { node: d, target: d, text: m.text }; }
  return { node: el('div', 'msg ' + m.role, m.text), target: null };
}
function rerenderLog(animateLast = 0) {
  const log = $('#log'); log.innerHTML = '';
  const msgs = state.chat.slice(-80);
  msgs.forEach((m, i) => {
    const r = msgNode(m);
    if (r.target && i >= msgs.length - animateLast) queue.push(r); else { if (r.target) r.target.textContent = r.text; log.appendChild(r.node); }
  });
  pump(); scrollDown();
}
function addMessages(msgs) { for (const m of msgs) { const r = msgNode(m); if (r.target) queue.push(r); else queue.push({ ...r, instant: true }); } pump(); }
function pump() {
  if (revealing || !queue.length) return;
  const r = queue.shift(); $('#log').appendChild(r.node); scrollDown();
  if (r.instant || !r.target) {
    if (r.node.classList.contains('discovery')) music.sfx('discovery'); else if (r.node.classList.contains('event')) music.sfx('event');
    return pump();
  }
  const speed = [0, 1, 2, 4][settings.textSpeed] ?? 2;
  if (!speed) { r.target.textContent = r.text; return pump(); }
  let i = 0; revealing = r;
  const step = () => {
    if (revealing !== r) return;
    i = Math.min(r.text.length, i + speed * (lang() === 'ar' ? 1 : 1.5));
    r.target.textContent = r.text.slice(0, Math.ceil(i));
    if (i % 40 < speed) scrollDown();
    if (i >= r.text.length) { revealing = null; scrollDown(); pump(); } else requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}
function finishReveal() { if (revealing) { revealing.target.textContent = revealing.text; revealing = null; } while (queue.length) { const r = queue.shift(); if (r.target) r.target.textContent = r.text; $('#log').appendChild(r.node); } scrollDown(); }
function scrollDown() { const log = $('#log'); log.scrollTop = log.scrollHeight; }

async function submit(text) {
  if (busy || !text.trim()) return;
  busy = true; $('#sendBtn').disabled = true;
  finishReveal();
  addMessages([{ role: 'player', text }]);
  const w = el('div', 'writing'); w.innerHTML = `<svg class="i quill"><use href="#i-quill"/></svg>`; w.append(t('writing', lang()));
  $('#log').appendChild(w); scrollDown();
  const before = state.player.location;
  try {
    const res = await takeTurn(state, text, { ai } );
    w.remove();
    if (res.warning && ai) toast(t('aiFellBack', lang()));
    addMessages(res.messages);
    writeSave(state);
  } catch (err) {
    w.remove(); toast(String(err?.message || err));
  } finally {
    busy = false; $('#sendBtn').disabled = false; renderHud();
    if (state.player.location !== before) music.setMood(moodForLocation(LOCATIONS[state.player.location]));
  }
}

function toast(msg) { const tEl = $('#toast'); tEl.textContent = msg; tEl.classList.remove('hidden'); clearTimeout(toast.tm); toast.tm = setTimeout(() => tEl.classList.add('hidden'), 3500); }

// ------------------------------------------------------------ side panels
function insertText(s) { const i = $('#input'); i.value = (i.value ? i.value.trimEnd() + ' ' : '') + s; i.focus(); closeSheet(); autoGrow(); }
function openSheet(kind) {
  const l = lang(); const body = $('#sideBody'); body.innerHTML = '';
  const head = el('h2'); head.append(el('span', '', t(kind === 'settings' ? 'settings' : 't' + kind[0].toUpperCase() + kind.slice(1), l)));
  const x = el('button', 'iconbtn'); x.innerHTML = '<svg class="i"><use href="#i-x"/></svg>'; x.onclick = closeSheet; head.append(x);
  body.append(head);
  ({ character: panelCharacter, inventory: panelInventory, journal: panelJournal, people: panelPeople, map: panelMap, chronicle: panelChronicle, settings: panelSettings })[kind](body, l);
  $('#sheet').classList.remove('hidden');
}
function closeSheet() { $('#sheet').classList.add('hidden'); }
function kv(pairs) { const d = el('div', 'kv'); for (const [k, v] of pairs) d.append(el('span', '', k), el('span', '', String(v))); return d; }

function panelCharacter(b, l) {
  const p = state.player;
  b.append(el('p', '', `${p.name} — ${L(BACKGROUNDS[p.background].name, l)}`));
  b.append(kv([[t('level', l), p.level], [t('health', l), `${p.hp}/${p.maxHp}`], [t('hunger', l), Math.round(p.hunger)], [t('fatigue', l), Math.round(p.fatigue)], [t('silver', l), p.gold]]));
  const xpb = el('div', 'bar'); const xi = el('i'); xi.style.width = `${Math.min(100, (p.xp / xpForCharLevel(p.level)) * 100)}%`; xpb.append(xi); b.append(xpb);
  b.append(el('h3', '', t('stats', l)));
  b.append(kv(STAT_KEYS.map((k) => [L(STAT_NAMES[k], l), p.stats[k]])));
  b.append(el('h3', '', t('skills', l)));
  b.append(kv(SKILL_KEYS.map((k) => [L(SKILL_NAMES[k], l), p.skills[k].lvl])));
  b.append(el('h3', '', t('reputation', l)));
  const r = p.reputation;
  b.append(kv([[`${t('repLocal', l)} · ${l === 'ar' ? 'ميرفولد' : 'Mirefold'}`, r.local.mirefold], [`${t('repLocal', l)} · ${l === 'ar' ? 'كورفان' : 'Corvane'}`, r.local.corvane], [t('repPolitical', l), r.political], [t('repMilitary', l), r.military], [t('repCommercial', l), r.commercial], [t('repCriminal', l), r.criminal]]));
  b.append(el('h3', '', t('companions', l)));
  b.append(el('p', 'note', p.companions.length ? p.companions.map((c) => L(NPCS[c].name, l)).join(l === 'ar' ? '، ' : ', ') : t('noCompanions', l)));
}
function panelInventory(b, l) {
  const p = state.player; const ul = el('ul', 'list');
  if (!p.inventory.length) ul.append(el('li', '', t('empty', l)));
  for (const it of p.inventory) {
    const li = el('li', 'tappable'); const eq = Object.values(p.equipped).includes(it.id);
    li.append(el('b', '', `${itemName(it.id, l)} ×${it.qty}`));
    li.append(el('small', '', `${ITEMS[it.id].price ? ITEMS[it.id].price + ' ' + t('silver', l) : ''}${eq ? ' · ' + t('equipped', l) : ''}`));
    li.onclick = () => insertText(itemName(it.id, l));
    ul.append(li);
  }
  b.append(ul); b.append(el('p', 'note', t('hint', l)));
}
function panelJournal(b, l) {
  const p = state.player;
  b.append(el('h3', '', t('quests', l)));
  const ul = el('ul', 'list'); const qs = Object.entries(p.quests);
  if (!qs.length) ul.append(el('li', '', t('empty', l)));
  for (const [id, q] of qs) { const li = el('li'); li.append(el('b', '', L(QUESTS[id].title, l)), el('small', '', `${t(q.status, l)} — ${L(QUESTS[id].desc, l)}`)); ul.append(li); }
  b.append(ul);
  b.append(el('h3', '', t('knowledge', l)));
  const kn = el('ul', 'list');
  const discoveries = state.events.filter((e) => ['discovery', 'secret_learned', 'quest_offered'].includes(e.type)).slice(-15).reverse();
  if (!discoveries.length) kn.append(el('li', '', t('empty', l)));
  for (const e of discoveries) kn.append(el('li', '', L(e.text, l)));
  b.append(kn);
}
function panelPeople(b, l) {
  const ul = el('ul', 'list'); const here = npcsAt(state, state.player.location);
  const ids = [...new Set([...here, ...state.player.known.npcs])];
  if (!ids.length) ul.append(el('li', '', t('empty', l)));
  for (const id of ids) {
    const n = NPCS[id]; const st = state.npcs[id]; const band = attitudeBand(st.attitude);
    const li = el('li', 'tappable');
    li.append(el('span', 'att ' + band, band === 'warm' ? (l === 'ar' ? 'ودود' : 'warm') : band === 'cold' ? (l === 'ar' ? 'بارد' : 'cold') : band === 'hostile' ? (l === 'ar' ? 'معادٍ' : 'hostile') : (l === 'ar' ? 'محايد' : 'neutral')));
    li.append(el('b', '', L(n.name, l)));
    li.append(el('small', '', `${L(n.role, l)}${here.includes(id) ? ' · ' + t('here', l) : ''}${!st.alive ? (l === 'ar' ? ' · متوفّى' : ' · dead') : ''}`));
    li.onclick = () => insertText(L(n.name, l));
    ul.append(li);
  }
  b.append(ul); b.append(el('p', 'note', t('hint', l)));
}
function panelMap(b, l) {
  const p = state.player; const ul = el('ul', 'list');
  const exits = Object.fromEntries((LOCATIONS[p.location].exits || []).filter((e) => !e.hidden || p.flags[e.hidden]).map((e) => [e.to, e.minutes]));
  for (const id of p.known.locations) {
    const li = el('li', 'tappable');
    li.append(el('b', '', locName(id, l)));
    li.append(el('small', '', id === p.location ? t('youAreHere', l) : exits[id] ? t('minutes', l, { n: exits[id] }) : L(LOCATIONS[id].region === 'corvane' ? { en: 'Corvane', ar: 'كورفان' } : { en: 'The vale', ar: 'الوادي' }, l)));
    li.onclick = () => insertText(locName(id, l));
    ul.append(li);
  }
  b.append(ul);
  b.append(el('p', 'note', l === 'ar' ? 'تظهر الأماكن الجديدة حين تسمع بها أو تصل إليها.' : 'New places appear as you hear of them or reach them.'));
}
function panelChronicle(b, l) {
  b.append(el('p', 'note', t('chronicleIntro', l)));
  const ul = el('ul', 'list');
  if (!state.chronicle.length) ul.append(el('li', '', t('empty', l)));
  for (const c of [...state.chronicle].reverse()) { const li = el('li'); li.append(el('b', '', `${t('day', l, { d: c.day })} · ${L(TIME_WORDS[c.season], l)} ${c.year}`), el('small', '', L(c.text, l))); ul.append(li); }
  b.append(ul);
}
function panelSettings(b, l) {
  const s = el('div', 'settings');
  const row = (label, input) => { const lab = el('label', '', label); s.append(lab, input); return input; };
  const langSel = document.createElement('select'); langSel.className = 'field';
  langSel.innerHTML = '<option value="ar">العربية</option><option value="en">English</option>'; langSel.value = settings.lang;
  langSel.onchange = () => { setLang(langSel.value); openSheet('settings'); };
  row(t('language', l), langSel);
  const mus = document.createElement('select'); mus.className = 'field';
  mus.innerHTML = `<option value="1">${t('on', l)}</option><option value="0">${t('off', l)}</option>`; mus.value = settings.music ? '1' : '0';
  mus.onchange = () => { settings.music = mus.value === '1'; saveSettings(settings); music.setEnabled(settings.music); renderHud(); };
  row(t('music', l), mus);
  const vol = document.createElement('input'); vol.type = 'range'; vol.min = 0; vol.max = 1; vol.step = 0.05; vol.value = settings.volume;
  vol.oninput = () => { settings.volume = +vol.value; music.setVolume(settings.volume); saveSettings(settings); };
  row(t('volume', l), vol);
  const sp = document.createElement('input'); sp.type = 'range'; sp.min = 0; sp.max = 3; sp.step = 1; sp.value = settings.textSpeed;
  sp.oninput = () => { settings.textSpeed = +sp.value; saveSettings(settings); };
  row(t('textSpeed', l), sp);
  const url = document.createElement('input'); url.className = 'field'; url.type = 'url'; url.placeholder = 'https://…'; url.value = settings.serverUrl; url.dir = 'ltr';
  row(t('serverUrl', l), url);
  const tok = document.createElement('input'); tok.className = 'field'; tok.type = 'password'; tok.value = settings.appToken; tok.dir = 'ltr';
  row(t('appToken', l), tok);
  s.append(el('p', 'note', t('serverNote', l)));
  const status = el('p', 'note');
  const test = el('button', 'btn small', t('test', l));
  test.onclick = async () => {
    settings.serverUrl = url.value.trim(); settings.appToken = tok.value.trim(); saveSettings(settings);
    status.textContent = '…'; const h = await connectAi();
    status.textContent = !h ? t('connFail', l) : h.ai ? t('connOk', l, { m: h.models?.narrator || h.ai }) : t('connNoAi', l);
  };
  s.append(test, status);
  if (state) {
    s.append(el('h3', '', l === 'ar' ? 'الحفظ' : 'Save'));
    const ex = el('button', 'btn small', t('exportSave', l));
    ex.onclick = () => { const blob = new Blob([JSON.stringify(state)], { type: 'application/json' }); const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = `chronicle-${state.player.name}.json`; a.click(); };
    const menu = el('button', 'btn small', t('toMenu', l)); menu.onclick = () => { closeSheet(); writeSave(state); toTitle(); };
    s.append(ex, document.createTextNode(' '), menu);
  }
  const imp = el('button', 'btn small', t('importSave', l));
  imp.onclick = () => { const f = document.createElement('input'); f.type = 'file'; f.accept = 'application/json'; f.onchange = async () => { try { const st = JSON.parse(await f.files[0].text()); if (!st.player) throw 0; state = st; writeSave(state); closeSheet(); enterGame(false); } catch { toast('✗'); } }; f.click(); };
  const del = el('button', 'btn small', t('deleteSave', l));
  del.onclick = () => { const v = window.prompt(t('confirmDelete', l)); if (v && /^(delete|احذف)$/i.test(v.trim())) { deleteSave(); state = null; closeSheet(); toTitle(); } };
  s.append(document.createTextNode(' '), imp, document.createTextNode(' '), del);
  b.append(s);
}

// ------------------------------------------------------------ wiring
function autoGrow() { const i = $('#input'); i.style.height = 'auto'; i.style.height = Math.min(140, i.scrollHeight) + 'px'; }
function wire() {
  $('#veil').onclick = async () => { $('#veil').classList.add('hidden'); toTitle(); if (settings.music) await music.start('title'); else music.init(); };
  $('#langBtn').onclick = () => setLang(lang() === 'ar' ? 'en' : 'ar');
  $('#newBtn').onclick = () => { show('create'); renderCreate(); $('#cErr').textContent = ''; setTimeout(() => $('#cName').focus(), 50); };
  $('#continueBtn').onclick = () => { state = loadSave(); if (state) enterGame(false); };
  $('#titleSettingsBtn').onclick = () => openSheet('settings');
  $('#cBack').onclick = toTitle;
  $('#cStart').onclick = startNew;
  $('#composer').onsubmit = (e) => { e.preventDefault(); const v = $('#input').value; $('#input').value = ''; autoGrow(); submit(v); };
  $('#input').addEventListener('keydown', (e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); $('#composer').requestSubmit(); } });
  $('#input').addEventListener('input', autoGrow);
  $('#log').addEventListener('click', finishReveal);
  document.querySelectorAll('.tabs button').forEach((b) => { b.onclick = () => openSheet(b.dataset.panel); });
  $('#sheet').addEventListener('click', (e) => { if (e.target.id === 'sheet') closeSheet(); });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeSheet(); });
  // Android hardware back button (Capacitor): close the panel first, then go to the title screen.
  window.Capacitor?.Plugins?.App?.addListener?.('backButton', () => {
    if (!$('#sheet').classList.contains('hidden')) closeSheet();
    else if (!$('#game').classList.contains('hidden')) { if (state) writeSave(state); toTitle(); }
    else window.Capacitor.Plugins.App.exitApp();
  });
  $('#musicBtn').onclick = () => { settings.music = !settings.music; saveSettings(settings); music.setEnabled(settings.music); if (settings.music && !music.mood) music.start(moodForLocation(LOCATIONS[state.player.location])); renderHud(); };
  document.addEventListener('visibilitychange', () => { if (document.hidden) { if (state) writeSave(state); music.ctx?.suspend(); } else if (settings.music) music.ctx?.resume(); });
  window.addEventListener('online', connectAi);
}

applyLang(); wire(); connectAi();
window.__game = { get state() { return state; }, music };
