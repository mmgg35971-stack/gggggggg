// Minstrel: an original, procedurally performed medieval soundtrack.
// Everything is synthesised live with the Web Audio API (no audio files):
//   - lute/oud: Karplus-Strong plucked strings (pre-rendered per pitch)
//   - recorder: sine + breath noise + delayed vibrato
//   - hurdy-gurdy drone: detuned saws through a lowpass
//   - frame drum (daf): pitched thump + skin noise; "tek" rim hits
//   - bells and a wordless choir pad for temples and ruins
// Moods change with the player's location. The title screen plays the
// composed theme "The Ballad of the Ashen Road".

const MODES = {
  dorian: [0, 2, 3, 5, 7, 9, 10], aeolian: [0, 2, 3, 5, 7, 8, 10], phrygian: [0, 1, 3, 5, 7, 8, 10],
  hijaz: [0, 1, 4, 5, 7, 8, 10], mixolydian: [0, 2, 4, 5, 7, 9, 10]
};
const mtof = (m) => 440 * Math.pow(2, (m - 69) / 12);

// mood presets: tonic (midi), mode, beat seconds, beats per bar, instrument mix
export const MOODS = {
  title: { theme: true },
  village: { tonic: 62, mode: 'dorian', beat: 0.62, bar: 3, lute: 1, flute: 0.5, drone: 0.35, drum: 0, density: 0.65 },
  tavern: { tonic: 67, mode: 'mixolydian', beat: 0.2, bar: 6, lute: 1, flute: 0.9, drone: 0.25, drum: 1, density: 0.9, jig: true },
  wilds: { tonic: 57, mode: 'aeolian', beat: 0.85, bar: 4, lute: 0.25, flute: 0.8, drone: 0.55, drum: 0, density: 0.35, wind: 0.35 },
  ruins: { tonic: 52, mode: 'phrygian', beat: 1.0, bar: 4, lute: 0, flute: 0.45, drone: 0.6, drum: 0, density: 0.3, bells: 1, wind: 0.25 },
  temple: { tonic: 57, mode: 'aeolian', beat: 1.1, bar: 4, lute: 0, flute: 0.2, drone: 0.2, drum: 0, density: 0.3, bells: 0.6, choir: 1 },
  town: { tonic: 62, mode: 'hijaz', beat: 0.34, bar: 4, lute: 1, flute: 0.6, drone: 0.3, drum: 0.8, density: 0.75 },
  danger: { tonic: 50, mode: 'phrygian', beat: 0.3, bar: 4, lute: 0.8, flute: 0.3, drone: 0.6, drum: 1, density: 0.6, ostinato: true }
};

// "The Ballad of the Ashen Road" — original theme, D dorian, 3/4. [midi, beats]
const THEME = [
  [69, 2], [74, 1], [72, 1], [69, 1], [67, 1], [65, 2], [67, 1], [69, 3],
  [69, 2], [72, 1], [74, 1], [76, 1], [74, 1], [72, 1], [69, 1], [67, 1], [69, 3],
  [74, 2], [76, 1], [77, 2], [76, 1], [74, 1], [72, 1], [69, 1], [72, 3],
  [74, 1], [72, 1], [69, 1], [67, 2], [65, 1], [64, 1], [65, 1], [67, 1], [62, 3]
];
// bass roots per bar of the theme (12 bars), D dorian harmony: Dm C F Am ...
const THEME_BASS = [50, 48, 53, 45, 50, 48, 55, 45, 50, 53, 48, 57, 50, 55, 48, 50];

export const BALLAD = {
  en: ['Down the ashen road the barley bends,', 'and the glass hill hums where the old world ends.', 'Light no candle for the ones who fell,', 'the Mother keeps them, and she keeps them well.'],
  ar: ['على الطريقِ الرماديِّ ينحني الشعيرْ،', 'وتلُّ الزجاجِ يطنُّ حيث انتهى الزمنُ الأخيرْ.', 'لا تُشعلوا شمعةً لمن سقطوا هناكْ،', 'فالأمُّ تحفظهمْ، ونِعمَ الحِفاظُ ذاكْ.']
};

export class Minstrel {
  constructor() {
    this.ctx = null; this.mood = null; this.volume = 0.55; this.enabled = true;
    this.buses = {}; this.ksCache = new Map(); this.timer = null; this.rngSeed = 1234567;
  }
  rand() { // small LCG so phrases vary but are cheap
    this.rngSeed = (this.rngSeed * 1664525 + 1013904223) >>> 0; return this.rngSeed / 4294967296;
  }
  init() {
    if (this.ctx) return;
    const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return;
    const ctx = (this.ctx = new AC());
    this.master = ctx.createGain(); this.master.gain.value = this.volume;
    const comp = ctx.createDynamicsCompressor(); comp.threshold.value = -18; comp.ratio.value = 3;
    this.master.connect(comp).connect(ctx.destination);
    this.reverb = ctx.createConvolver(); this.reverb.buffer = this.impulse(2.8, 2.2);
    this.wet = ctx.createGain(); this.wet.gain.value = 0.32;
    this.reverb.connect(this.wet).connect(this.master);
    this.noiseBuf = this.makeNoise(2);
  }
  async start(mood = 'title') { this.init(); if (!this.ctx) return; if (this.ctx.state === 'suspended') await this.ctx.resume(); this.setMood(mood, true); }
  setVolume(v) { this.volume = v; if (this.master) this.master.gain.setTargetAtTime(this.enabled ? v : 0, this.ctx.currentTime, 0.2); }
  setEnabled(on) { this.enabled = on; if (this.master) this.master.gain.setTargetAtTime(on ? this.volume : 0, this.ctx.currentTime, 0.3); }

  setMood(mood, force = false) {
    if (!this.ctx || (!force && mood === this.mood)) return;
    if (!MOODS[mood]) mood = 'village';
    const now = this.ctx.currentTime;
    // fade out the previous bus
    if (this.bus) { const old = this.bus; old.gain.setTargetAtTime(0, now, 0.8); setTimeout(() => old.disconnect(), 5000); }
    this.bus = this.ctx.createGain(); this.bus.gain.value = 0; this.bus.gain.setTargetAtTime(1, now + 0.1, 1.0);
    this.dry = this.bus; this.bus.connect(this.master);
    this.send = this.ctx.createGain(); this.send.gain.value = 1; this.bus.connect(this.send).connect(this.reverb);
    this.mood = mood; this.preset = MOODS[mood];
    this.nextTime = now + 0.3; this.barIndex = 0; this.themePos = 0; this.phrase = null;
    this.stopLongVoices(); this.startLongVoices();
    if (!this.timer) this.timer = setInterval(() => this.tick(), 60);
  }
  stop() { clearInterval(this.timer); this.timer = null; this.stopLongVoices(); if (this.bus) this.bus.gain.setTargetAtTime(0, this.ctx.currentTime, 0.3); this.mood = null; }

  // ---------------------------------------------------------- scheduler
  tick() {
    const ahead = this.ctx.currentTime + 0.4;
    while (this.nextTime < ahead) {
      if (this.preset.theme) this.scheduleThemeBar(this.nextTime); else this.scheduleBar(this.nextTime);
    }
  }

  scheduleThemeBar(t) {
    const beat = 0.58; const pass = Math.floor(this.barIndex / 16);
    // collect notes for this bar (3 beats)
    let acc = 0; let pos = this.themePos; const notes = [];
    while (acc < 3 - 1e-6) { const [m, b] = THEME[pos % THEME.length]; notes.push([m, b, acc]); acc += b; pos++; }
    this.themePos = pos % THEME.length;
    const leadIsLute = pass % 2 === 1;
    for (const [m, b, at] of notes) {
      if (leadIsLute) this.lute(m, t + at * beat, 0.5, 1.6);
      else this.flute(m, t + at * beat, b * beat * 0.95, 0.32);
    }
    const root = THEME_BASS[this.barIndex % THEME_BASS.length];
    this.lute(root, t, 0.45, 2.2); this.lute(root + 7, t + beat, 0.25, 1.4); this.lute(root + 12, t + 2 * beat, 0.22, 1.2);
    if (pass >= 1) { this.drum(t, 0.5, true); this.drum(t + 2 * beat, 0.25, false); }
    this.droneTo(root - 12);
    this.barIndex++; this.nextTime = t + 3 * beat;
  }

  scheduleBar(t) {
    const P = this.preset; const scale = MODES[P.mode];
    const deg = (d) => P.tonic + scale[((d % 7) + 7) % 7] + 12 * Math.floor(d / 7);
    if (!this.phrase || this.phraseBar >= 4) this.newPhrase();
    const bar = this.phrase[this.phraseBar];
    // melody
    for (const n of bar) {
      if (n.rest) continue;
      const m = deg(n.d) + 12;
      if (P.flute && (this.phraseBar % 2 === 0 || this.rand() < P.flute)) this.flute(m, t + n.at * P.beat, n.len * P.beat * 0.92, 0.26 * P.flute);
      else if (P.lute) this.lute(m, t + n.at * P.beat, 0.45 * P.lute, 1.2);
    }
    // accompaniment: lute arpeggios or ostinato on chord root (I, VII, VI, V cycle)
    const prog = [0, 6, 5, 4]; const rootDeg = prog[(this.barIndex >> (P.jig ? 0 : 1)) % 4];
    if (P.lute) {
      const pattern = P.jig ? [0, 4, 7, 4, 2, 4] : P.ostinato ? [0, 0, 1, 0] : P.bar === 3 ? [0, 4, 7] : [0, 4, 7, 4];
      pattern.forEach((iv, i) => { if (i < P.bar || P.jig) this.lute(deg(rootDeg) - 12 + (iv === 7 ? 12 : iv === 4 ? scale[4] - scale[0] : iv === 2 ? scale[2] : iv === 1 ? scale[1] : 0), t + i * P.beat, (i === 0 ? 0.42 : 0.24) * P.lute, 1.4); });
    }
    if (P.drum) {
      if (P.jig) { this.drum(t, 0.55, true); this.drum(t + 3 * P.beat, 0.4, true); this.drum(t + 2 * P.beat, 0.22, false); this.drum(t + 5 * P.beat, 0.22, false); }
      else { this.drum(t, 0.55, true); this.drum(t + P.beat * 1.5, 0.2, false); this.drum(t + P.beat * 2, 0.4, true); this.drum(t + P.beat * 3, 0.25, false); if (P.ostinato) this.drum(t + P.beat * 3.5, 0.25, false); }
    }
    if (P.bells && this.rand() < 0.5 * P.bells) this.bell(deg(this.pick([0, 4, 2])) + 12, t + this.rand() * P.bar * P.beat, 0.18 * P.bells);
    if (P.choir && this.barIndex % 2 === 0) this.choir([deg(rootDeg), deg(rootDeg + 2), deg(rootDeg + 4)], t, P.bar * P.beat * 2, 0.08);
    this.droneTo(deg(0) - 12);
    this.phraseBar++; this.barIndex++;
    this.nextTime = t + P.bar * P.beat;
  }

  pick(a) { return a[Math.floor(this.rand() * a.length)]; }

  // A 4-bar phrase built from a motif: statement, sequence, variation, cadence.
  newPhrase() {
    const P = this.preset; const beats = P.bar;
    const rhythms = P.jig ? [[1, 1, 1, 1, 1, 1], [2, 1, 2, 1], [3, 1, 1, 1], [1, 2, 1, 2]]
      : beats === 3 ? [[2, 1], [1, 1, 1], [3], [1, 2]] : [[1, 1, 2], [2, 1, 1], [1, 1, 1, 1], [3, 1], [4], [2, 2]];
    const motifR = this.pick(rhythms);
    let d = this.pick([0, 2, 4]); const motif = [];
    for (const r of motifR) { motif.push({ d, len: r }); d += this.pick([-1, 1, 1, -1, 2, -2, 0]); d = Math.max(-2, Math.min(8, d)); }
    const shift = this.pick([1, 2, -1]);
    const toBar = (notes, transpose = 0, vary = false) => {
      let at = 0; const out = [];
      for (const n of notes) {
        const rest = this.rand() > P.density + (vary ? 0 : 0.15);
        out.push({ d: n.d + transpose + (vary && this.rand() < 0.4 ? this.pick([-1, 1]) : 0), len: n.len, at, rest });
        at += n.len;
      }
      return out;
    };
    const cadenceR = this.pick(rhythms);
    const cad = []; let at = 0; let cd = motif[motif.length - 1].d;
    cadenceR.forEach((r, i) => { const last = i === cadenceR.length - 1; cd = last ? this.pick([0, 4, 7]) : cd + (cd > 3 ? -1 : 1); cad.push({ d: cd, len: r, at, rest: false }); at += r; });
    this.phrase = [toBar(motif), toBar(motif, shift), toBar(motif, 0, true), cad];
    this.phraseBar = 0;
  }

  // ---------------------------------------------------------- instruments
  out(node, wet = 1) { node.connect(this.dry); if (wet) { const g = this.ctx.createGain(); g.gain.value = wet; node.connect(g).connect(this.send); } }

  ks(freq, dur = 2.2) {
    const key = Math.round(freq * 10);
    if (this.ksCache.has(key)) return this.ksCache.get(key);
    const sr = this.ctx.sampleRate; const len = Math.floor(sr * dur);
    const buf = this.ctx.createBuffer(1, len, sr); const out = buf.getChannelData(0);
    const N = Math.max(2, Math.round(sr / freq)); const line = new Float32Array(N);
    for (let i = 0; i < N; i++) line[i] = (Math.random() * 2 - 1) * (0.6 + 0.4 * Math.sin(i / N * Math.PI)); // softened pluck
    let idx = 0; const decay = 0.996 - Math.min(0.006, freq / 120000);
    for (let i = 0; i < len; i++) {
      const nxt = (idx + 1) % N; const v = line[idx];
      line[idx] = decay * 0.5 * (v + line[nxt]);
      out[i] = v; idx = nxt;
    }
    this.ksCache.set(key, buf);
    if (this.ksCache.size > 64) this.ksCache.delete(this.ksCache.keys().next().value);
    return buf;
  }
  lute(midi, t, vel = 0.4, len = 1.5) {
    const ctx = this.ctx; const src = ctx.createBufferSource(); src.buffer = this.ks(mtof(midi));
    const g = ctx.createGain(); g.gain.setValueAtTime(vel, t); g.gain.setTargetAtTime(0, t + len, 0.25);
    const body = ctx.createBiquadFilter(); body.type = 'peaking'; body.frequency.value = 420; body.gain.value = 5; body.Q.value = 1.2;
    const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 3200;
    src.connect(body).connect(lp).connect(g); this.out(g, 0.6);
    src.start(t); src.stop(t + len + 1.2);
  }
  flute(midi, t, len, vel = 0.25) {
    const ctx = this.ctx; const f = mtof(midi);
    const o = ctx.createOscillator(); o.type = 'sine'; o.frequency.value = f;
    const o2 = ctx.createOscillator(); o2.type = 'triangle'; o2.frequency.value = f * 2; const g2 = ctx.createGain(); g2.gain.value = 0.08;
    const vib = ctx.createOscillator(); vib.frequency.value = 5.2; const vg = ctx.createGain(); vg.gain.setValueAtTime(0, t); vg.gain.linearRampToValueAtTime(f * 0.006, t + Math.min(0.5, len));
    vib.connect(vg).connect(o.frequency);
    const g = ctx.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(vel, t + 0.07); g.gain.setValueAtTime(vel * 0.85, t + Math.max(0.08, len - 0.08)); g.gain.linearRampToValueAtTime(0.0001, t + len + 0.12);
    const n = ctx.createBufferSource(); n.buffer = this.noiseBuf; const bp = ctx.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = f * 1.5; bp.Q.value = 2; const ng = ctx.createGain(); ng.gain.value = 0.05;
    n.connect(bp).connect(ng).connect(g);
    o.connect(g); o2.connect(g2).connect(g); this.out(g, 0.9);
    for (const s of [o, o2, vib, n]) { s.start(t); s.stop(t + len + 0.2); }
  }
  droneTo(midi) {
    if (!this.droneVoices || !this.preset.drone && !this.preset.theme) return;
    const f = mtof(midi); const now = this.ctx.currentTime;
    this.droneVoices.forEach((o, i) => o.frequency.setTargetAtTime(f * [1, 1.5, 1.003][i], now, 0.6));
  }
  startLongVoices() {
    const ctx = this.ctx; const P = this.preset; const lvl = P.theme ? 0.22 : P.drone;
    this.long = [];
    if (lvl) {
      const g = ctx.createGain(); g.gain.value = 0; g.gain.setTargetAtTime(0.06 * lvl, ctx.currentTime, 2);
      const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 700; lp.Q.value = 3;
      const lfo = ctx.createOscillator(); lfo.frequency.value = 0.13; const lg = ctx.createGain(); lg.gain.value = 180; lfo.connect(lg).connect(lp.frequency); lfo.start();
      this.droneVoices = [0, 1, 2].map(() => { const o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.value = 73.4; o.connect(lp); o.start(); return o; });
      lp.connect(g); this.out(g, 0.7);
      this.long.push(g, lfo, ...this.droneVoices);
    } else this.droneVoices = null;
    if (P.wind) {
      const n = ctx.createBufferSource(); n.buffer = this.noiseBuf; n.loop = true;
      const bp = ctx.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = 500; bp.Q.value = 0.7;
      const lfo = ctx.createOscillator(); lfo.frequency.value = 0.07; const lg = ctx.createGain(); lg.gain.value = 300; lfo.connect(lg).connect(bp.frequency);
      const g = ctx.createGain(); g.gain.value = 0; g.gain.setTargetAtTime(0.05 * P.wind, ctx.currentTime, 3);
      n.connect(bp).connect(g); this.out(g, 0.5); n.start(); lfo.start();
      this.long.push(n, lfo, g);
    }
  }
  stopLongVoices() {
    if (!this.long) return; const now = this.ctx.currentTime;
    for (const v of this.long) { if (v.gain) v.gain.setTargetAtTime(0, now, 0.6); else { try { v.stop(now + 3); } catch { /* already stopped */ } } }
    this.long = []; this.droneVoices = null;
  }
  drum(t, vel, low) {
    const ctx = this.ctx;
    if (low) {
      const o = ctx.createOscillator(); o.type = 'sine'; o.frequency.setValueAtTime(110, t); o.frequency.exponentialRampToValueAtTime(48, t + 0.18);
      const g = ctx.createGain(); g.gain.setValueAtTime(vel * 0.9, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.35);
      o.connect(g); this.out(g, 0.25); o.start(t); o.stop(t + 0.4);
    }
    const n = ctx.createBufferSource(); n.buffer = this.noiseBuf;
    const f = ctx.createBiquadFilter(); f.type = low ? 'bandpass' : 'highpass'; f.frequency.value = low ? 220 : 2600; f.Q.value = 0.9;
    const g = ctx.createGain(); g.gain.setValueAtTime(vel * (low ? 0.35 : 0.3), t); g.gain.exponentialRampToValueAtTime(0.001, t + (low ? 0.12 : 0.06));
    n.connect(f).connect(g); this.out(g, 0.3); n.start(t, this.rand()); n.stop(t + 0.15);
  }
  bell(midi, t, vel = 0.15) {
    const ctx = this.ctx; const f = mtof(midi);
    [[1, 1], [2.76, 0.5], [5.4, 0.25], [8.93, 0.12]].forEach(([r, a]) => {
      const o = ctx.createOscillator(); o.frequency.value = f * r; const g = ctx.createGain();
      g.gain.setValueAtTime(vel * a, t); g.gain.exponentialRampToValueAtTime(0.0001, t + 4 / Math.sqrt(r));
      o.connect(g); this.out(g, 1.2); o.start(t); o.stop(t + 4.5);
    });
  }
  choir(midis, t, len, vel) {
    const ctx = this.ctx;
    const f1 = ctx.createBiquadFilter(); f1.type = 'bandpass'; f1.frequency.value = 730; f1.Q.value = 6;
    const f2 = ctx.createBiquadFilter(); f2.type = 'bandpass'; f2.frequency.value = 1090; f2.Q.value = 7;
    const g = ctx.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(vel, t + len * 0.35); g.gain.linearRampToValueAtTime(0.0001, t + len);
    const mix = ctx.createGain(); mix.gain.value = 1;
    for (const m of midis) for (const det of [-6, 5]) {
      const o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.value = mtof(m); o.detune.value = det;
      o.connect(mix); o.start(t); o.stop(t + len + 0.1);
    }
    mix.connect(f1).connect(g); mix.connect(f2).connect(g); this.out(g, 1.4);
  }
  // one-shot UI sounds
  sfx(kind) {
    if (!this.ctx || !this.enabled) return; const t = this.ctx.currentTime + 0.02;
    if (!this.dry) return;
    if (kind === 'discovery') { this.bell(81, t, 0.12); this.bell(88, t + 0.18, 0.08); }
    else if (kind === 'event') this.bell(74, t, 0.07);
    else if (kind === 'quill') this.lute(86, t, 0.08, 0.3);
  }

  impulse(seconds, decay) {
    const sr = this.ctx.sampleRate; const len = Math.floor(sr * seconds); const buf = this.ctx.createBuffer(2, len, sr);
    for (let c = 0; c < 2; c++) { const d = buf.getChannelData(c); for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, decay); }
    return buf;
  }
  makeNoise(seconds) {
    const sr = this.ctx.sampleRate; const buf = this.ctx.createBuffer(1, sr * seconds, sr); const d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1; return buf;
  }
}

export function moodForLocation(loc) { return loc?.music || 'village'; }
