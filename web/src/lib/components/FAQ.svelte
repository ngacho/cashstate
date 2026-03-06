<script lang="ts">
	type FaqItem = { question: string; answer: string };

	const faqs: FaqItem[] = [
		{
			question: 'Is CashState free?',
			answer: 'Yes. CashState is completely free to use. No ads, no premium tiers, no selling your data.',
		},
		{
			question: 'What is SimpleFIN?',
			answer: 'SimpleFIN is like a window on a safe: it lets people look at, but not touch your financial information. And you control who can look through the window.',
		},
		{
			question: 'Why SimpleFIN?',
			answer: 'All access is read-only. You can read and comprehend the spec in a single day. Banks don\'t have to pay anyone to use it (like they do with QFX). Ubiquitous use will help train people that giving out their account credentials is unacceptable.',
		},
		{
			question: 'How do I get a SimpleFIN token?',
			answer: 'Sign up at simplefin.org, link your bank, and generate an access token. Paste it into CashState to start syncing.',
		},
		{
			question: 'Is my data secure?',
			answer: 'SimpleFIN provides read-only access — nobody can move money through it. Your data is encrypted and we never store your bank credentials.',
		},
		{
			question: 'What can I track?',
			answer: 'Net worth, spending breakdowns, AI-powered categorization, budgets, and financial goal progress — all synced automatically.',
		},
	];

	let open = $state<number | null>(null);

	function toggle(i: number) {
		open = open === i ? null : i;
	}
</script>

<section class="faq" id="faq">
	<div class="inner">
		<div class="label">FAQ</div>
		<h2>Questions & answers.</h2>
		<div class="list">
			{#each faqs as faq, i}
				<button class="item" class:open={open === i} onclick={() => toggle(i)}>
					<div class="q">
						<span class="q-text">{faq.question}</span>
						<span class="icon" class:rotated={open === i}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"/></svg>
						</span>
					</div>
					{#if open === i}
						<p class="a">{faq.answer}</p>
					{/if}
				</button>
			{/each}
		</div>
	</div>
</section>

<style>
	.faq {
		padding: 120px 24px;
	}

	.inner {
		max-width: 640px;
		margin: 0 auto;
		text-align: center;
	}

	.label {
		display: inline-block;
		padding: 6px 16px;
		background: var(--accent-light);
		color: var(--accent);
		border-radius: 100px;
		font-size: 12px;
		font-weight: 600;
		letter-spacing: 0.06em;
		text-transform: uppercase;
		margin-bottom: 24px;
	}

	h2 {
		font-family: var(--font-serif);
		font-size: clamp(36px, 5vw, 52px);
		font-weight: 400;
		color: var(--text-primary);
		letter-spacing: -0.02em;
		line-height: 1.15;
		margin-bottom: 48px;
	}

	.list {
		display: flex;
		flex-direction: column;
		text-align: left;
	}

	.item {
		text-align: left;
		width: 100%;
		padding: 24px 0;
		border-top: 1px solid var(--border);
		transition: padding 0.2s;
	}

	.item:last-child {
		border-bottom: 1px solid var(--border);
	}

	.q {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 16px;
	}

	.q-text {
		font-size: 16px;
		font-weight: 600;
		color: var(--text-primary);
		line-height: 1.4;
	}

	.icon {
		flex-shrink: 0;
		color: var(--text-muted);
		transition: transform 0.3s ease;
		display: flex;
	}

	.icon.rotated {
		transform: rotate(180deg);
	}

	.a {
		font-size: 15px;
		color: var(--text-secondary);
		line-height: 1.8;
		margin-top: 16px;
		padding-right: 40px;
	}

	@media (max-width: 640px) {
		.faq { padding: 80px 20px; }
		.a { padding-right: 0; }
	}
</style>
