// See https://svelte.dev/docs/kit/types#app.d.ts
// for information about these interfaces
declare global {
	namespace App {
		// interface Error {}
		// interface Locals {}
		// interface PageData {}
		// interface PageState {}
		// interface Platform {}
	}

	interface Window {
		turnstile: {
			render: (
				selector: string,
				options: {
					sitekey: string;
					callback: (token: string) => void;
					'expired-callback'?: () => void;
					theme?: 'light' | 'dark' | 'auto';
					size?: 'normal' | 'compact' | 'flexible';
				}
			) => string;
			reset: (widgetId?: string) => void;
			remove: (widgetId?: string) => void;
		};
	}
}

export {};
