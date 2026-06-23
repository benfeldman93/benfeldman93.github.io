// Supabase Edge Function: anthropic-proxy
// Holds the Anthropic API key server-side as a secret and forwards
// /v1/messages requests. The browser never sees the key.
//
// Deploy:
//   supabase functions deploy anthropic-proxy
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//
// JWT verification is on by default, so only logged-in PayShare users
// (whose Supabase access token is sent by supabase-js) can call it.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  if (!ANTHROPIC_API_KEY) {
    return json({ error: { message: "Server is missing ANTHROPIC_API_KEY secret." } });
  }

  try {
    const body = await req.json();
    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(body),
    });
    // Pass the upstream JSON straight through (including any Anthropic error),
    // always as 200 so the frontend can read `data.error` uniformly.
    const data = await resp.json();
    return json(data);
  } catch (e) {
    return json({ error: { message: String(e) } });
  }
});

function json(obj: unknown) {
  return new Response(JSON.stringify(obj), {
    status: 200,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
