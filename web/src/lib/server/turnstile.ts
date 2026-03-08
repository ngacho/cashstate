import { env } from '$env/dynamic/private';

interface TurnstileResponse {
	success: boolean;
	'error-codes': string[];
}

export async function verifyTurnstile(token: string, ip: string): Promise<boolean> {
	const res = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({
			secret: env.TURNSTILE_SECRET_KEY,
			response: token,
			remoteip: ip
		})
	});
	const data: TurnstileResponse = await res.json();
	return data.success === true;
}
