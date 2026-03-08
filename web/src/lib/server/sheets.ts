import { google } from 'googleapis';
import { env } from '$env/dynamic/private';

function getAuth() {
	return new google.auth.JWT({
		email: env.GOOGLE_SERVICE_ACCOUNT_EMAIL,
		key: env.GOOGLE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
		scopes: ['https://www.googleapis.com/auth/spreadsheets']
	});
}

export async function appendRow(tab: string, values: string[]) {
	const auth = getAuth();
	const sheets = google.sheets({ version: 'v4', auth });

	await sheets.spreadsheets.values.append({
		spreadsheetId: env.GOOGLE_SHEET_ID,
		range: `${tab}!A:Z`,
		valueInputOption: 'USER_ENTERED',
		requestBody: { values: [values] }
	});
}
