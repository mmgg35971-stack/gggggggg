// Anthropic (Claude) provider. Uses Structured Outputs so every reply is valid
// JSON for our schemas, prompt caching on the static system prompts, and
// model routing: a fast model parses intent, a stronger one narrates.
import Anthropic from '@anthropic-ai/sdk';

export function createAnthropicProvider({
  apiKey = process.env.ANTHROPIC_API_KEY,
  fastModel = process.env.AI_FAST_MODEL || 'claude-haiku-5-5',
  narratorModel = process.env.AI_NARRATOR_MODEL || 'claude-opus-5-5',
  narratorEffort = process.env.AI_NARRATOR_EFFORT || 'low',
  timeoutMs = 45000
} = {}) {
  const client = new Anthropic({ apiKey, timeout: timeoutMs, maxRetries: 2 });

  async function complete({ model, system, user, schema, maxTokens, effort }) {
    const usesFallbacks = /^claude-(opus-5-5|opus-5|sonnet-5-5|fable-5)/.test(model);
    const params = {
      model,
      max_tokens: maxTokens,
      system: [{ type: 'text', text: system, cache_control: { type: 'ephemeral' } }],
      messages: [{ role: 'user', content: user }],
      output_config: { format: { type: 'json_schema', schema }, ...(effort ? { effort } : {}) }
    };
    const msg = usesFallbacks
      ? await client.beta.messages.create({ ...params, betas: ['server-side-fallback-2026-07-01'], fallbacks: 'default' })
      : await client.messages.create(params);
    if (msg.stop_reason === 'refusal') throw new Error('ai_refusal');
    if (msg.stop_reason === 'max_tokens') throw new Error('ai_truncated');
    const text = msg.content.filter((b) => b.type === 'text').map((b) => b.text).join('');
    return { data: JSON.parse(text), usage: msg.usage };
  }

  return {
    name: 'anthropic',
    models: { fast: fastModel, narrator: narratorModel },
    interpret: ({ system, user, schema }) => complete({ model: fastModel, system, user, schema, maxTokens: 2000, effort: 'low' }),
    narrate: ({ system, user, schema }) => complete({ model: narratorModel, system, user, schema, maxTokens: 6000, effort: narratorEffort })
  };
}
