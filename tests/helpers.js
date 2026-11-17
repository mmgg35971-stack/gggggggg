import { newGame } from '../shared/state.js';
import { applyActions } from '../shared/engine.js';

export function game(opts = {}) {
  return newGame({ name: 'Test', background: 'soldier', lang: 'en', seed: 12345, ...opts });
}
const BLANK = { npc: null, item: null, qty: null, destination: null, approach: null, topic: null, utterance: null, skill: null, difficulty: null, hours: null, description: null };
export const act = (type, extra = {}) => ({ ...BLANK, type, ...extra });
/** Apply actions and return the results array. */
export function run(state, ...actions) { return applyActions(state, actions).results; }
