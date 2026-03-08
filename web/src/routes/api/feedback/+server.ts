import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { appendRow } from '$lib/server/sheets';
import { verifyTurnstile } from '$lib/server/turnstile';
import { rateLimit } from '$lib/server/rateLimit';

export const POST: RequestHandler = async ({ request, getClientAddress }) => {
	const ip = getClientAddress();
	if (!rateLimit(ip)) {
		return json({ error: 'Too many requests' }, { status: 429 });
	}

	const { email, type, message, source, turnstileToken } = await request.json();

	if (!turnstileToken || typeof turnstileToken !== 'string') {
		return json({ error: 'Verification required' }, { status: 403 });
	}

	if (!(await verifyTurnstile(turnstileToken, ip))) {
		return json({ error: 'Verification failed' }, { status: 403 });
	}

	if (!message || typeof message !== 'string') {
		return json({ error: 'Message is required' }, { status: 400 });
	}

	const validTypes = ['bug', 'feature', 'general'] as const;
	const feedbackType = validTypes.includes(type) ? type : 'general';

	try {
		await appendRow('feedback', [
			new Date().toISOString(),
			email?.trim() ?? '',
			feedbackType,
			message.trim(),
			source ?? 'web'
		]);
	} catch {
		return json({ error: 'Failed to save. Please try again.' }, { status: 500 });
	}

	return json({ status: 'submitted' });
};
