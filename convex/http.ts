import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { internal } from "./_generated/api";

const http = httpRouter();

// Manual Clerk/Svix webhook verification using Web Crypto API
// (svix npm package uses Node.js Buffer which isn't available in Convex runtime)
async function verifyWebhook(
  secret: string,
  body: string,
  svixId: string,
  svixTimestamp: string,
  svixSignature: string
): Promise<boolean> {
  // Strip "whsec_" prefix if present
  const rawSecret = secret.startsWith("whsec_") ? secret.slice(6) : secret;
  console.log("Webhook secret (first 8 chars after prefix strip):", rawSecret.slice(0, 8));
  const secretBytes = base64Decode(rawSecret);

  // Build the signed content: "msg_id.timestamp.body"
  const signedContent = `${svixId}.${svixTimestamp}.${body}`;
  const encoder = new TextEncoder();

  const key = await crypto.subtle.importKey(
    "raw",
    secretBytes.buffer as ArrayBuffer,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(signedContent).buffer as ArrayBuffer
  );

  const computedSig = base64Encode(new Uint8Array(signature));

  // svix-signature header contains space-separated signatures like "v1,<base64>"
  const expectedSigs = svixSignature.split(" ");
  for (const sig of expectedSigs) {
    const sigValue = sig.split(",")[1];
    if (sigValue === computedSig) {
      return true;
    }
  }
  return false;
}

function base64Decode(str: string): Uint8Array {
  // Convert URL-safe base64 to standard base64
  let b64 = str.replace(/-/g, "+").replace(/_/g, "/");
  // Add padding if needed
  while (b64.length % 4 !== 0) {
    b64 += "=";
  }
  const binaryStr = atob(b64);
  const bytes = new Uint8Array(binaryStr.length);
  for (let i = 0; i < binaryStr.length; i++) {
    bytes[i] = binaryStr.charCodeAt(i);
  }
  return bytes;
}

function base64Encode(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

http.route({
  path: "/clerk-webhook",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const webhookSecret = process.env.CLERK_WEBHOOK_SECRET;
    if (!webhookSecret) {
      console.error("Missing CLERK_WEBHOOK_SECRET env var");
      return new Response("Server misconfigured", { status: 500 });
    }

    const svixId = request.headers.get("svix-id");
    const svixTimestamp = request.headers.get("svix-timestamp");
    const svixSignature = request.headers.get("svix-signature");

    if (!svixId || !svixTimestamp || !svixSignature) {
      return new Response("Missing svix headers", { status: 400 });
    }

    const body = await request.text();

    // Log incoming webhook for debugging
    try {
      const parsed = JSON.parse(body);
      console.log("Webhook received:", parsed.type, "for:", parsed.data?.id);
    } catch {
      console.log("Webhook body (not JSON):", body.slice(0, 200));
    }

    const isValid = await verifyWebhook(
      webhookSecret,
      body,
      svixId,
      svixTimestamp,
      svixSignature
    );
    if (!isValid) {
      console.error("Webhook signature verification failed");
      return new Response("Invalid signature", { status: 400 });
    }

    const event = JSON.parse(body);
    const eventType = event.type as string;

    if (eventType === "user.created" || eventType === "user.updated") {
      const { id, email_addresses, first_name, last_name } = event.data;
      const primaryEmail =
        email_addresses?.find(
          (e: any) => e.id === event.data.primary_email_address_id
        )?.email_address ?? email_addresses?.[0]?.email_address ?? "";

      await ctx.runMutation(internal.users.upsertFromWebhook, {
        clerkId: id,
        email: primaryEmail,
        firstName: first_name ?? undefined,
        lastName: last_name ?? undefined,
      });
    }

    if (eventType === "user.deleted") {
      const { id } = event.data;
      if (id) {
        await ctx.runMutation(internal.users.deleteFromWebhook, {
          clerkId: id,
        });
      }
    }

    return new Response("OK", { status: 200 });
  }),
});

// Simple endpoint for iOS to check if a user exists by clerkId
// Bypasses ConvexClientWithAuth which can hang during auth settlement
http.route({
  path: "/user-exists",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const url = new URL(request.url);
    const clerkId = url.searchParams.get("clerkId");
    if (!clerkId) {
      return new Response(JSON.stringify({ exists: false }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const user = await ctx.runQuery(internal.usersHelpers._getByClerkId, {
      clerkId,
    });

    return new Response(JSON.stringify({ exists: user !== null }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }),
});

export default http;
