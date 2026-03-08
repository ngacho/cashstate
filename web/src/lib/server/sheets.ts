import { env } from '$env/dynamic/private';

function base64url(data: Uint8Array): string {
	let binary = '';
	for (const byte of data) {
		binary += String.fromCharCode(byte);
	}
	return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64urlEncode(str: string): string {
	return base64url(new TextEncoder().encode(str));
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
	const pemContents = pem
		.replace(/-----BEGIN PRIVATE KEY-----/g, '')
		.replace(/-----END PRIVATE KEY-----/g, '')
		.replace(/\s/g, '');

	const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

	return crypto.subtle.importKey(
		'pkcs8',
		binaryDer,
		{ name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
		false,
		['sign']
	);
}

async function getAccessToken(): Promise<string> {
	const now = Math.floor(Date.now() / 1000);
	const header = base64urlEncode(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
	const payload = base64urlEncode(
		JSON.stringify({
			iss: env.GOOGLE_SERVICE_ACCOUNT_EMAIL,
			scope: 'https://www.googleapis.com/auth/spreadsheets',
			aud: 'https://oauth2.googleapis.com/token',
			iat: now,
			exp: now + 3600
		})
	);

	const signingInput = `${header}.${payload}`;
	const key = await importPrivateKey(env.GOOGLE_PRIVATE_KEY?.replace(/\\n/g, '\n') ?? '');
	const signature = await crypto.subtle.sign(
		'RSASSA-PKCS1-v1_5',
		key,
		new TextEncoder().encode(signingInput)
	);

	const jwt = `${signingInput}.${base64url(new Uint8Array(signature))}`;

	const res = await fetch('https://oauth2.googleapis.com/token', {
		method: 'POST',
		headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
		body: new URLSearchParams({
			grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
			assertion: jwt
		})
	});

	const data: { access_token: string } = await res.json();
	return data.access_token;
}

export async function appendRow(tab: string, values: string[]) {
	const token = await getAccessToken();
	const sheetId = env.GOOGLE_SHEET_ID;

	const res = await fetch(
		`https://sheets.googleapis.com/v4/spreadsheets/${sheetId}/values/${encodeURIComponent(tab)}!A:Z:append?valueInputOption=USER_ENTERED`,
		{
			method: 'POST',
			headers: {
				Authorization: `Bearer ${token}`,
				'Content-Type': 'application/json'
			},
			body: JSON.stringify({ values: [values] })
		}
	);

	if (!res.ok) {
		const err = await res.text();
		throw new Error(`Sheets API error ${res.status}: ${err}`);
	}
}
