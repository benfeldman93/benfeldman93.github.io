// Supabase Edge Function: gemini-proxy
// Holds the Google AI Studio API key server-side and forwards receipt
// scan requests to Gemini 2.5 Flash. The browser never sees the key.
//
// Deploy:
//   supabase functions deploy gemini-proxy
//   supabase secrets set GEMINI_API_KEY=AQ.your_key_here

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const MODEL = "gemini-2.5-flash";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  if (!GEMINI_API_KEY) {
    return json({ error: "Server is missing GEMINI_API_KEY secret." });
  }

  try {
    const { image_base64, image_mime_type, prompt } = await req.json();

    const url = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}`;

    const resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{
          parts: [
            {
              inline_data: {
                mime_type: image_mime_type || "image/jpeg",
                data: image_base64,
              },
            },
            { text: prompt },
          ],
        }],
        generationConfig: {
          response_mime_type: "application/json",
          temperature: 0,
        },
      }),
    });

    const data = await resp.json();

    if (!resp.ok) {
      const msg = data?.error?.message || `Gemini API error ${resp.status}`;
      return json({ error: `Gemini ${resp.status}: ${msg}` });
    }

    const candidate = data?.candidates?.[0];
    if (!candidate) {
      const blocked = data?.promptFeedback?.blockReason;
      return json({ error: blocked ? `Blocked by Gemini: ${blocked}` : "Gemini returned no candidates." });
    }
    if (candidate.finishReason && candidate.finishReason !== "STOP" && candidate.finishReason !== "MAX_TOKENS") {
      return json({ error: `Gemini stopped early (${candidate.finishReason}). Try a clearer image.` });
    }
    const text = candidate?.content?.parts?.[0]?.text ?? "{}";
    return json({ text });
  } catch (e) {
    return json({ error: String(e) });
  }
});

function json(obj: unknown) {
  return new Response(JSON.stringify(obj), {
    status: 200,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
