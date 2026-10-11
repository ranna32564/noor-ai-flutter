import 'dotenv/config';
import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors({ origin: process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',') : false }));
app.use(express.json({ limit: '15mb' }));
const port = Number(process.env.PORT || 3000);
const timeoutMs = Number(process.env.PROVIDER_TIMEOUT_MS || 45000);
const apiAccessToken = process.env.API_ACCESS_TOKEN || '';
function requireAppToken(req, res, next) {
  if (!apiAccessToken) return res.status(503).json({ error: 'Backend API_ACCESS_TOKEN is not configured.' });
  if (req.headers.authorization !== `Bearer ${apiAccessToken}`) return res.status(401).json({ error: 'Unauthorized.' });
  return next();
}

const systemPrompt = `You are Noor AI, an Islamic-focused assistant. Answer only Islamic questions and Islamic content tasks such as Islamic captions. Politely decline unrelated requests. Never fabricate Quran verses, Arabic religious text, hadith wording, references, numbers, authenticity grades or scholarly quotations. Clearly state uncertainty, distinguish established teachings from disputed issues, and recommend a qualified scholar for complex rulings. Do not label ingredients Haram solely because they are absent from a database. For choking, breathing difficulty or severe illness, advise emergency medical help first. Respond in the language used by the user.`;

app.get('/health', (_req, res) => res.json({ ok: true, service: 'Noor AI backend', configuredProviders: {
  gemini: Boolean(process.env.GEMINI_API_KEY), openrouter: Boolean(process.env.OPENROUTER_API_KEY)
}}));

function timeoutSignal() {
  return AbortSignal.timeout(timeoutMs);
}
app.post('/ask', requireAppToken, async (req, res) => {
  const { message, provider = process.env.DEFAULT_PROVIDER || 'gemini', model, imageBase64, imageMimeType } = req.body ?? {};
  if ((!String(message || '').trim()) && !imageBase64) return res.status(400).json({ error: 'message or image required' });
  if (!['gemini', 'openrouter'].includes(provider)) return res.status(400).json({ error: 'provider must be gemini or openrouter' });
  try {
    let response;
    if (provider === 'gemini') {
      const key = process.env.GEMINI_API_KEY;
      if (!key) return res.status(503).json({ error: 'Gemini is not configured on the backend.' });
      const modelId = model || process.env.GEMINI_MODEL || 'gemini-2.5-flash';
      const parts = [{ text: `${systemPrompt}

User request: ${String(message || 'Write a respectful Islamic caption for this image.')}` }];
      if (imageBase64) {
        const mime = ['image/jpeg', 'image/png', 'image/webp'].includes(imageMimeType) ? imageMimeType : 'image/jpeg';
        parts.push({ inline_data: { mime_type: mime, data: imageBase64 } });
      }
      response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(modelId)}:generateContent`, {
        method: 'POST', headers: { 'content-type': 'application/json', 'x-goog-api-key': key },
        body: JSON.stringify({ contents: [{ role: 'user', parts }], generationConfig: { temperature: 0.2, maxOutputTokens: 1400 } }),
        signal: timeoutSignal()
      });
    } else {
      const key = process.env.OPENROUTER_API_KEY;
      if (!key) return res.status(503).json({ error: 'OpenRouter is not configured on the backend.' });
      const modelId = model || process.env.OPENROUTER_MODEL || 'openrouter/auto';
      const content = [{ type: 'text', text: `${systemPrompt}

User request: ${String(message || 'Write a respectful Islamic caption for this image.')}` }];
      if (imageBase64) {
        const mime = ['image/jpeg', 'image/png', 'image/webp'].includes(imageMimeType) ? imageMimeType : 'image/jpeg';
        content.push({ type: 'image_url', image_url: { url: `data:${mime};base64,${imageBase64}` } });
      }
      response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${key}`, 'X-Title': 'Noor AI' },
        body: JSON.stringify({ model: modelId, messages: [{ role: 'user', content }], temperature: 0.2, max_tokens: 1400 }),
        signal: timeoutSignal()
      });
    }
    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      const providerMessage = body?.error?.message || body?.message || `Provider returned HTTP ${response.status}`;
      return res.status(response.status === 429 ? 429 : response.status >= 500 ? 502 : response.status).json({ error: providerMessage, provider, status: response.status });
    }
    const answer = provider === 'gemini'
      ? (body?.candidates?.[0]?.content?.parts || []).map(p => p.text || '').join('\n').trim()
      : String(body?.choices?.[0]?.message?.content || '').trim();
    if (!answer) return res.status(502).json({ error: 'Provider response was valid JSON but contained no answer.' });
    return res.json({ answer, provider, model: model || (provider === 'gemini' ? process.env.GEMINI_MODEL : process.env.OPENROUTER_MODEL) });
  } catch (error) {
    const timeout = error?.name === 'TimeoutError' || error?.name === 'AbortError';
    console.error('Noor AI request failed:', error?.message || error);
    return res.status(timeout ? 504 : 502).json({ error: timeout ? 'Provider request timed out. Please retry.' : 'Provider request failed. Check network, model ID, quota and backend logs.' });
  }
});

app.post('/test-provider', requireAppToken, async (req, res) => {
  const { provider, model } = req.body ?? {};
  if (!['gemini', 'openrouter'].includes(provider)) return res.status(400).json({ ok: false, error: 'provider must be gemini or openrouter' });
  try {
    // Use the same real provider path by issuing a local request to the ask handler is intentionally avoided;
    // test requests call the provider API independently to return an unambiguous result.
    let r;
    if (provider === 'gemini') {
      const key = process.env.GEMINI_API_KEY;
      if (!key) return res.status(503).json({ ok: false, error: 'GEMINI_API_KEY is not configured.' });
      r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model || process.env.GEMINI_MODEL || 'gemini-2.5-flash')}:generateContent`, {
        method: 'POST', headers: { 'content-type': 'application/json', 'x-goog-api-key': key },
        body: JSON.stringify({ contents: [{ parts: [{ text: 'Reply with exactly: Noor AI connection test OK' }] }], generationConfig: { maxOutputTokens: 20 } }), signal: timeoutSignal()
      });
    } else {
      const key = process.env.OPENROUTER_API_KEY;
      if (!key) return res.status(503).json({ ok: false, error: 'OPENROUTER_API_KEY is not configured.' });
      r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${key}`, 'X-Title': 'Noor AI' },
        body: JSON.stringify({ model: model || process.env.OPENROUTER_MODEL || 'openrouter/auto', messages: [{ role: 'user', content: 'Reply with exactly: Noor AI connection test OK' }], max_tokens: 20 }), signal: timeoutSignal()
      });
    }
    const j = await r.json().catch(() => ({}));
    const valid = provider === 'gemini' ? Array.isArray(j?.candidates) && j.candidates.length > 0 : Array.isArray(j?.choices) && j.choices.length > 0;
    if (!r.ok || !valid) return res.status(r.status || 502).json({ ok: false, error: j?.error?.message || 'No valid response returned by provider.' });
    return res.json({ ok: true, provider, message: 'Live provider response received.' });
  } catch (error) {
    const timeout = error?.name === 'TimeoutError' || error?.name === 'AbortError';
    return res.status(timeout ? 504 : 502).json({ ok: false, error: timeout ? 'Provider test timed out.' : 'Provider test failed. Check network and backend logs.' });
  }
});

app.listen(port, '0.0.0.0', () => console.log(`Noor AI backend listening on port ${port}`));
