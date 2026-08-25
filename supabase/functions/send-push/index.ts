import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PROJECT_ID = "k-shop-3a502";

function b64urlEncode(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function b64urlString(s: string): string {
  return b64urlEncode(new TextEncoder().encode(s));
}

async function getAccessToken(): Promise<string> {
  const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: sa.token_uri,
    iat: now,
    exp: now + 3600,
  };
  const data = b64urlString(JSON.stringify(header)) + "." + b64urlString(JSON.stringify(claim));

  const pem = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(data)),
  );
  const jwt = data + "." + b64urlEncode(sig);

  const res = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }).toString(),
  });
  const json = await res.json();
  return json.access_token as string;
}

async function sendToToken(token: string, title: string, body: string, chatId: string, image?: string) {
  const accessToken = await getAccessToken();
  const notification: { title: string; body: string; image?: string } = { title, body };
  if (image && image.trim().length > 0) notification.image = image;

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token,
          notification,
          data: { chat_id: chatId },
          android: { priority: "high" },
        },
      }),
    },
  );
  if (!res.ok) {
    const txt = await res.text();
    console.error("FCM send error", res.status, txt);
  }
  return res;
}

Deno.serve(async (req) => {
  try {
    const {
      user_id,
      sender_id,
      sender_name,
      title,
      body: bodyText,
      chat_id,
      image: imageOverride,
      broadcast,
      exclude_user_id,
    } = await req.json();
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // جلب اسم/صورة المرسل إن وُجد
    let resolvedName: string | undefined = sender_name;
    let senderImage: string | undefined;
    if ((!resolvedName || !imageOverride) && sender_id) {
      const { data: p } = await supabase
        .from("profiles")
        .select("full_name, avatar_url")
        .eq("id", sender_id)
        .single();
      if (p) {
        if (!resolvedName) resolvedName = (p as { full_name?: string }).full_name;
        senderImage = (p as { avatar_url?: string }).avatar_url;
      }
    }
    const image = (imageOverride && String(imageOverride).trim().length > 0)
      ? String(imageOverride)
      : senderImage;

    let tokens: { token: string; user_id?: string }[] = [];
    if (broadcast) {
      const { data: all } = await supabase.from("push_tokens").select("token, user_id");
      const userIds = [...new Set((all ?? []).map((t) => t.user_id).filter(Boolean))];
      const { data: prefs } = await supabase
        .from("profiles")
        .select("id, product_notifications")
        .in("id", userIds as string[]);
      const allowed = new Set(
        (prefs ?? [])
          .filter((p) => p.product_notifications !== false)
          .map((p) => p.id),
      );
      tokens = (all ?? []).filter(
        (t) => allowed.has(t.user_id) && t.user_id !== (exclude_user_id ?? ""),
      );
    } else if (user_id) {
      const { data: t } = await supabase.from("push_tokens").select("token").eq("user_id", user_id);
      tokens = (t ?? []) as { token: string }[];
    }

    const notifTitle =
      resolvedName && resolvedName.trim().length > 0
        ? resolvedName
        : (title ?? "رسالة جديدة");

    for (const row of tokens) {
      await sendToToken(row.token, notifTitle, bodyText ?? "", chat_id ?? "", image);
    }
    return new Response(JSON.stringify({ ok: true, sent: tokens.length }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
