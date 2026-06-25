import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import webpush from "npm:web-push@3";

serve(async (req) => {
  const { groupId, expenseDesc, payerName } = await req.json();
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  webpush.setVapidDetails(
    "mailto:benfeldman933@gmail.com",
    Deno.env.get("VAPID_PUBLIC_KEY")!,
    Deno.env.get("VAPID_PRIVATE_KEY")!
  );

  const { data: subs } = await supabase
    .from("push_subscriptions")
    .select("endpoint, p256dh, auth")
    .eq("group_id", groupId);

  await Promise.allSettled((subs || []).map(s =>
    webpush.sendNotification(
      { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
      JSON.stringify({
        title: "SplitStack",
        body:  `${payerName} added: ${expenseDesc}`,
        url:   "/"
      })
    )
  ));

  return new Response("ok");
});
