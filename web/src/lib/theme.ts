export const theme = {
	colors: {
		primary: '#0D9488',       // teal - main brand color
		primaryDark: '#0F766E',   // darker teal for hover
		primaryLight: '#CCFBF1',  // light teal for badges/pills
		accent: '#EC4899',        // pink accent
		accentLight: '#FDF2F8',   // light pink background
		highlight: '#EAB308',     // yellow highlight
		highlightLight: '#FEF9C3',// light yellow background
		dark: '#0F172A',          // near-black for headings
		text: '#475569',          // slate gray for body text
		textLight: '#94A3B8',     // lighter text
		white: '#FFFFFF',
		background: '#FAFAFA',    // off-white background
		card: '#FFFFFF',
		border: '#E2E8F0',
	},
	fonts: {
		heading: "'Inter', system-ui, -apple-system, sans-serif",
		body: "'Inter', system-ui, -apple-system, sans-serif",
	},
} as const;

export const carouselItems = [
	'the state of your cash',
	'your net worth',
	'financial goals',
	'your budget',
	'your spending',
] as const;
