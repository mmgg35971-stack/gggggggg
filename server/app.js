// HTTP backend. Stateless: the game engine and saves live on the player's
// device; this server only holds the AI key and talks to the AI provider.
// Swap providers by passing a different object with interpret()/narrate().
import express from 'express';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { INTERPRET_SCHEMA, NARRATE_SCHEMA, sanitizeInterpretation, sanitizeNarration } from '../shared/schemas.js';
import { interpreterSystem, narratorSystem } from './ai/prompts.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

export function createApp({ provider = null, appToken = process.env.APP_TOKEN || '', rateLimitPerMin = Number(process.env.RATE_LIMIT_PER_MIN || 40), log = console } = {}) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '64kb' }));

  // CORS: the Android app (capacitor) calls from its own origin.
  app.use((req, res, next) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Headers', 'content-type, x-app-token');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    next();
  });

  // simple per-IP rate limit (cost protection)
  const hits = new Map();
  function limited(req) {
    const key = req.ip || 'x'; const now = Date.now();
    const arr = (hits.get(key) || []).filter((t) => now - t < 60000);
    arr.push(now); hits.set(key, arr);
    return arr.length > rateLimitPerMin;
  }
  function guard(req, res) {
    if (appToken && req.get('x-app-token') !== appToken) { res.status(401).json({ error: 'unauthorized' }); return false; }
    if (!provider) { res.status(503).json({ error: 'ai_not_configured' }); return false; }
    if (limited(req)) { res.status(429).json({ error: 'rate_limited' }); return false; }
    return true;
  }

  const interpSys = interpreterSystem();
  const narrSys = narratorSystem();

  app.get('/api/health', (req, res) => res.json({ ok: true, ai: provider ? provider.name : null, models: provider?.models || null, tokenRequired: !!appToken }));

  app.post('/api/ai/interpret', async (req, res) => {
    if (!guard(req, res)) return;
    const { text, lang, context } = req.body || {};
    if (typeof text !== 'string' || !text.trim() || text.length > 600) return res.status(400).json({ error: 'bad_text' });
    try {
      const user = `CONTEXT:\n${JSON.stringify(context ?? {}).slice(0, 6000)}\n\nPLAYER (${lang === 'en' ? 'en' : 'ar'}):\n${text}`;
      const { data, usage } = await provider.interpret({ system: interpSys, user, schema: INTERPRET_SCHEMA });
      res.json({ ...sanitizeInterpretation(data), usage });
    } catch (err) {
      log.error?.('interpret failed:', err?.message || err);
      res.status(502).json({ error: 'ai_failed' });
    }
  });

  app.post('/api/ai/narrate', async (req, res) => {
    if (!guard(req, res)) return;
    const packet = req.body || {};
    if (!packet || !Array.isArray(packet.results)) return res.status(400).json({ error: 'bad_packet' });
    try {
      const user = `TURN PACKET:\n${JSON.stringify(packet).slice(0, 24000)}`;
      const { data, usage } = await provider.narrate({ system: narrSys, user, schema: NARRATE_SCHEMA });
      const allowed = Array.isArray(packet.allowed_npcs) ? packet.allowed_npcs : [];
      res.json({ ...sanitizeNarration(data, { allowedNpcs: allowed }), usage });
    } catch (err) {
      log.error?.('narrate failed:', err?.message || err);
      res.status(502).json({ error: 'ai_failed' });
    }
  });

  // The same web build that ships inside the APK, for playing in a browser.
  app.use('/shared', express.static(path.join(ROOT, 'shared')));
  app.use(express.static(path.join(ROOT, 'app')));
  return app;
}
