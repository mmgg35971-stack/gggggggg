// Entry point: `npm start`. Reads ANTHROPIC_API_KEY from the environment.
// Without a key the server still serves the game; the client plays offline.
import { createApp } from './app.js';
import { createAnthropicProvider } from './ai/anthropic.js';

const port = Number(process.env.PORT || 8787);
const provider = process.env.ANTHROPIC_API_KEY ? createAnthropicProvider() : null;
createApp({ provider }).listen(port, () => {
  console.log(`Medieval AI RPG on http://localhost:${port}  (AI: ${provider ? provider.name + ' ' + JSON.stringify(provider.models) : 'not configured, offline mode'})`);
});
