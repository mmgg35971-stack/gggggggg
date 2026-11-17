// Device storage for saves and settings. In the Android app this is the
// WebView's persistent storage; in a browser it is the site's localStorage.
// Every access is guarded so a blocked storage never breaks the game.
const SAVE_KEY = 'dv.save.auto';
const SETTINGS_KEY = 'dv.settings';

function safeGet(k) { try { return localStorage.getItem(k); } catch { return null; } }
function safeSet(k, v) { try { localStorage.setItem(k, v); return true; } catch { return false; } }
function safeDel(k) { try { localStorage.removeItem(k); } catch { /* ignore */ } }

export function loadSave() {
  const raw = safeGet(SAVE_KEY); if (!raw) return null;
  try { const s = JSON.parse(raw); return s && s.version && s.player ? s : null; } catch { return null; }
}
export function writeSave(state) { return safeSet(SAVE_KEY, JSON.stringify(state)); }
export function deleteSave() { safeDel(SAVE_KEY); }

export const DEFAULT_SETTINGS = { lang: 'ar', serverUrl: '', appToken: '', music: true, volume: 0.55, textSpeed: 2 };
export function loadSettings() {
  try { return { ...DEFAULT_SETTINGS, ...(JSON.parse(safeGet(SETTINGS_KEY) || '{}')) }; } catch { return { ...DEFAULT_SETTINGS }; }
}
export function saveSettings(s) { safeSet(SETTINGS_KEY, JSON.stringify(s)); }
