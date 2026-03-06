<script lang="ts">
	type FaqItem = {
		question: string;
		answer: string;
	};

	const faqs: FaqItem[] = [
		{
			question: 'Is CashState free?',
			answer: 'Yes! CashState is completely free to use. We believe everyone deserves clear visibility into their finances without paying a premium for it.',
		},
		{
			question: 'What is SimpleFIN and why do I need it?',
			answer: 'SimpleFIN is like a window on a safe: it lets people look at, but not touch your financial information. And you control who can look through the window! You\'ll need a SimpleFIN account and access token to connect your bank data to CashState.',
		},
		{
			question: 'Why does CashState use SimpleFIN?',
			answer: 'All access through SimpleFIN is read-only — no one can move your money. You can read and comprehend the SimpleFIN spec in a single day. Banks don\'t have to pay anyone to use it (like they do with QFX). And ubiquitous use helps train people that giving out their account credentials is unacceptable.',
		},
		{
			question: 'How do I get a SimpleFIN token?',
			answer: 'Sign up for a SimpleFIN account at simplefin.org, link your bank, and generate an access token. Then paste that token into CashState to start syncing your financial data.',
		},
		{
			question: 'Is my financial data secure?',
			answer: 'Absolutely. SimpleFIN provides read-only access — nobody can make transactions or move money through it. Your data is encrypted end-to-end, and we never store your bank credentials. You stay in control at all times.',
		},
		{
			question: 'What can I track with CashState?',
			answer: 'CashState gives you a complete picture: net worth tracking, spending breakdowns with AI-powered categorization, budget management, and financial goal progress — all updated automatically when your accounts sync.',
		},
	];

	let openIndex = $state<number | null>(null);

	function toggle(index: number) {
		openIndex = openIndex === index ? null : index;
	}
</script>

<section class="faq" id="faq">
	<div class="faq-inner">
		<div class="section-header">
			<span class="section-pill">FAQ</span>
			<h2>Frequently asked questions</h2>
			<p>Everything you need to know about CashState and SimpleFIN.</p>
		</div>

		<div class="faq-list">
			{#each faqs as faq, i}
				<button
					class="faq-item"
					class:open={openIndex === i}
					onclick={() => toggle(i)}
				>
					<div class="faq-question">
						<span>{faq.question}</span>
						<svg
							class="chevron"
							width="20"
							height="20"
							viewBox="0 0 20 20"
							fill="none"
						>
							<path
								d="M5 7.5L10 12.5L15 7.5"
								stroke="currentColor"
								stroke-width="2"
								stroke-linecap="round"
								stroke-linejoin="round"
							/>
						</svg>
					</div>
					<div class="faq-answer">
						<p>{faq.answer}</p>
					</div>
				</button>
			{/each}
		</div>
	</div>
</section>

<style>
	.faq {
		padding: 6rem 2rem;
		background: var(--color-background);
	}

	.faq-inner {
		max-width: 720px;
		margin: 0 auto;
	}

	.section-header {
		text-align: center;
		margin-bottom: 3rem;
	}

	.section-pill {
		display: inline-block;
		padding: 0.4rem 1rem;
		background: var(--color-highlight-light);
		color: var(--color-highlight);
		border-radius: 100px;
		font-size: 0.85rem;
		font-weight: 600;
		margin-bottom: 1rem;
	}

	.section-header h2 {
		font-size: clamp(1.8rem, 4vw, 2.5rem);
		font-weight: 800;
		color: var(--color-dark);
		line-height: 1.2;
		margin-bottom: 1rem;
	}

	.section-header p {
		font-size: 1.1rem;
		color: var(--color-text);
	}

	.faq-list {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.faq-item {
		background: var(--color-white);
		border: 1px solid var(--color-border);
		border-radius: 16px;
		padding: 0;
		overflow: hidden;
		text-align: left;
		width: 100%;
		transition: border-color 0.2s;
	}

	.faq-item:hover {
		border-color: var(--color-primary);
	}

	.faq-item.open {
		border-color: var(--color-primary);
	}

	.faq-question {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1.25rem 1.5rem;
		font-size: 1rem;
		font-weight: 600;
		color: var(--color-dark);
		gap: 1rem;
	}

	.chevron {
		flex-shrink: 0;
		color: var(--color-text-light);
		transition: transform 0.3s ease;
	}

	.faq-item.open .chevron {
		transform: rotate(180deg);
		color: var(--color-primary);
	}

	.faq-answer {
		max-height: 0;
		overflow: hidden;
		transition: max-height 0.3s ease, padding 0.3s ease;
		padding: 0 1.5rem;
	}

	.faq-item.open .faq-answer {
		max-height: 300px;
		padding: 0 1.5rem 1.25rem;
	}

	.faq-answer p {
		font-size: 0.95rem;
		color: var(--color-text);
		line-height: 1.7;
	}
</style>
