# Waitlist & Feedback Forms

## Approach

Build the forms entirely in SvelteKit — web pages with API routes (`+server.ts`) that proxy submissions to **Google Sheets**. The iOS app opens a WebView pointing to the same pages. One implementation, one spam prevention layer, zero native iOS form code.

No Convex exposure. No third-party form branding. Fully custom UI.

## Why This Stack

| Option | Cost | Web | iOS | Looks Pro | Data Access |
|---|---|---|---|---|---|
| **SvelteKit + Google Sheets (chosen)** | Free | Native form | WebView | Yes (your UI) | Spreadsheet |
| Convex tables | Free | Native | Native | Yes | Dashboard only |
| Typeform / Tally | Free tier | Iframe/redirect | Webview | Meh (their brand) | Their dashboard |
| Formspree | Free (50/mo) | Native form | HTTPS POST | Yes | Their dashboard |
| Supabase | Free tier | Native | HTTPS POST | Yes | SQL dashboard |

**Why not Convex?** It works, but exposes your prod Convex URL for unauthenticated mutations. Keeping forms separate avoids that. Google Sheets also gives you a no-code view of all submissions without opening the Convex dashboard.

**Why not Formspree?** 50 submissions/month on free tier is tight. Google Sheets is unlimited and free.

## Architecture

```
[Web Browser]   ──/waitlist page──>  POST /api/waitlist  ──Turnstile + rate limit──>  Google Sheets
[Web Browser]   ──/feedback page──>  POST /api/feedback  ──Turnstile + rate limit──>  Google Sheets
[iOS WebView]   ──/feedback page──>  POST /api/feedback  ──Turnstile + rate limit──>  Google Sheets
```

iOS opens a WebView to the same `/feedback` page — Turnstile runs in the WebView just like a browser. Same spam protection, zero extra work.

All secrets (Google service account key, Turnstile secret) live in SvelteKit's server-side env (`$env/static/private`). Nothing reaches the client.

## Google Sheets Setup

1. Create a Google Cloud project (or use existing)
2. Enable the **Google Sheets API**
3. Create a **Service Account** → download JSON key
4. Create a Google Sheet with two tabs: `waitlist` and `feedback`
5. Share the sheet with the service account email (Editor access)
6. Store credentials as env vars in your deployment (Vercel/Cloudflare/etc)

### Sheet Structure

**Waitlist tab** — columns:
| timestamp | email | name | source |

**Feedback tab** — columns:
| timestamp | email | type | message | source |

## Implementation

### 1. Install dependency

```bash
cd web
npm install googleapis
```

### 2. Env vars

```env
GOOGLE_SERVICE_ACCOUNT_EMAIL=xxx@xxx.iam.gserviceaccount.com
GOOGLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n..."
GOOGLE_SHEET_ID=your-sheet-id-from-url
```

### 3. Sheets helper

```typescript
// src/lib/server/sheets.ts
import { google } from 'googleapis';
import {
  GOOGLE_SERVICE_ACCOUNT_EMAIL,
  GOOGLE_PRIVATE_KEY,
  GOOGLE_SHEET_ID
} from '$env/static/private';

const auth = new google.auth.JWT(
  GOOGLE_SERVICE_ACCOUNT_EMAIL,
  undefined,
  GOOGLE_PRIVATE_KEY.replace(/\\n/g, '\n'),
  ['https://www.googleapis.com/auth/spreadsheets']
);

const sheets = google.sheets({ version: 'v4', auth });

export async function appendRow(tab: string, values: string[]) {
  await sheets.spreadsheets.values.append({
    spreadsheetId: GOOGLE_SHEET_ID,
    range: `${tab}!A:Z`,
    valueInputOption: 'USER_ENTERED',
    requestBody: { values: [values] },
  });
}
```

### 4. Waitlist endpoint

```typescript
// src/routes/api/waitlist/+server.ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { appendRow } from '$lib/server/sheets';

export const POST: RequestHandler = async ({ request }) => {
  const { email, name, source } = await request.json();

  if (!email || typeof email !== 'string') {
    return json({ error: 'Email is required' }, { status: 400 });
  }

  await appendRow('waitlist', [
    new Date().toISOString(),
    email.trim().toLowerCase(),
    name?.trim() ?? '',
    source ?? 'web',
  ]);

  return json({ status: 'joined' });
};
```

### 5. Feedback endpoint

```typescript
// src/routes/api/feedback/+server.ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { appendRow } from '$lib/server/sheets';

export const POST: RequestHandler = async ({ request }) => {
  const { email, type, message, source } = await request.json();

  if (!message || typeof message !== 'string') {
    return json({ error: 'Message is required' }, { status: 400 });
  }

  const validTypes = ['bug', 'feature', 'general'];
  const feedbackType = validTypes.includes(type) ? type : 'general';

  await appendRow('feedback', [
    new Date().toISOString(),
    email?.trim() ?? '',
    feedbackType,
    message.trim(),
    source ?? 'web',
  ]);

  return json({ status: 'submitted' });
};
```

## Web Integration

### Waitlist (CTA section or Hero)

Replace the current "Download for free" CTA in `CTA.svelte` or add alongside it:

```svelte
<form onsubmit={handleJoin}>
  <input type="email" bind:value={email} placeholder="Enter your email" required />
  <button type="submit">Join waitlist</button>
</form>
```

```typescript
async function handleJoin(e: Event) {
  e.preventDefault();
  const res = await fetch('/api/waitlist', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, source: 'web' }),
  });
  if (res.ok) submitted = true;
}
```

### Feedback (new page or modal)

Add a `/feedback` route or a modal accessible from the Footer (add a "Feedback" link to the Support column):

```svelte
<form onsubmit={handleSubmit}>
  <select bind:value={type}>
    <option value="general">General</option>
    <option value="bug">Bug report</option>
    <option value="feature">Feature request</option>
  </select>
  <textarea bind:value={message} placeholder="What's on your mind?" required></textarea>
  <button type="submit">Send feedback</button>
</form>
```

## iOS Integration

Open a WebView to the SvelteKit feedback page. Turnstile works inside WebView, so spam protection is automatic.

```swift
// FeedbackWebView.swift
import SwiftUI
import WebKit

struct FeedbackWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        let url = URL(string: "\(Config.webURL)/feedback")!
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
```

**Usage** — present as a sheet from settings or a feedback button:
```swift
.sheet(isPresented: $showFeedback) {
    NavigationStack {
        FeedbackWebView()
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showFeedback = false }
                }
            }
    }
}
```

Add `webURL` to `Config.swift` pointing to your deployed SvelteKit app.

## Spam Prevention

Since iOS uses a WebView to the same pages, we only need web-level protection. Two layers:

### 1. Cloudflare Turnstile

Invisible CAPTCHA. Free, no user friction. Works in both browser and iOS WebView.

**Web side** — add to `app.html`:
```html
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
```

In form components:
```svelte
<div class="cf-turnstile" data-sitekey={PUBLIC_TURNSTILE_SITE_KEY} data-callback="onTurnstileVerify"></div>
```

**Server side verification:**
```typescript
// src/lib/server/turnstile.ts
import { TURNSTILE_SECRET_KEY } from '$env/static/private';

export async function verifyTurnstile(token: string, ip: string): Promise<boolean> {
  const res = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      secret: TURNSTILE_SECRET_KEY,
      response: token,
      remoteip: ip,
    }),
  });
  const data = await res.json();
  return data.success === true;
}
```

**Env vars:**
```env
PUBLIC_TURNSTILE_SITE_KEY=0x...
TURNSTILE_SECRET_KEY=0x...
```

### 2. Rate Limiting

Fallback layer. Limits requests per IP per time window.

```typescript
// src/lib/server/rateLimit.ts
const requests = new Map<string, { count: number; resetAt: number }>();

export function rateLimit(ip: string, maxRequests = 5, windowMs = 60_000): boolean {
  const now = Date.now();
  const entry = requests.get(ip);

  if (!entry || now > entry.resetAt) {
    requests.set(ip, { count: 1, resetAt: now + windowMs });
    return true;
  }

  if (entry.count >= maxRequests) return false;
  entry.count++;
  return true;
}
```

**Usage in endpoints:**
```typescript
export const POST: RequestHandler = async ({ request, getClientAddress }) => {
  const ip = getClientAddress();
  if (!rateLimit(ip)) {
    return json({ error: 'Too many requests' }, { status: 429 });
  }

  // verify turnstile token
  const { turnstileToken, ...data } = await request.json();
  if (!await verifyTurnstile(turnstileToken, ip)) {
    return json({ error: 'Verification failed' }, { status: 403 });
  }

  // ... process request
};
```

Note: In-memory rate limiting resets on deploy/restart. For production with multiple instances, use your hosting platform's built-in rate limiting (Vercel, Cloudflare, etc.) or Redis.

## Notifications (optional)

Get pinged when submissions come in:

- **Slack incoming webhook** — add a `fetch()` call in the API route after appending to sheets. Free.
- **Email via Resend** — free tier (100/day). Send yourself an email on each waitlist signup.
- **Just check the spreadsheet** — simplest. Set up Google Sheets mobile notifications for changes.

## Implementation Order

1. Google Cloud setup (service account, Sheets API, create spreadsheet)
2. Cloudflare Turnstile setup (get site key + secret key)
3. Add env vars to deployment
4. Create `src/lib/server/sheets.ts`, `src/lib/server/turnstile.ts`, `src/lib/server/rateLimit.ts`
5. Create `src/routes/api/waitlist/+server.ts` and `src/routes/api/feedback/+server.ts`
6. Add waitlist form to `CTA.svelte` or `Hero.svelte`
7. Create `/feedback` page, add link in `Footer.svelte`
8. Add `Config.webURL` to iOS, create `FeedbackWebView.swift`, present as sheet
9. (Optional) Slack/email notifications
