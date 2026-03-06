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
		<h2>Questions & answers.</h2>
		<div class="list">
			{#each faqs as faq, i}
				<button class="item" class:open={open === i} onclick={() => toggle(i)}>
					<div class="q">
						<span>{faq.question}</span>
						<span class="icon">{open === i ? '\u2212' : '+'}</span>
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
		padding: 100px 24px;
	}

	.inner {
		max-width: 680px;
		margin: 0 auto;
	}

	h2 {
		font-size: clamp(36px, 5vw, 56px);
		font-weight: 700;
		color: var(--text-primary);
		letter-spacing: -0.03em;
		line-height: 1.1;
		margin-bottom: 48px;
		text-align: center;
	}

	.list {
		display: flex;
		flex-direction: column;
	}

	.item {
		text-align: left;
		width: 100%;
		padding: 20px 0;
		border-top: 1px solid var(--border);
	}

	.item:last-child {
		border-bottom: 1px solid var(--border);
	}

	.q {
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-size: 16px;
		font-weight: 600;
		color: var(--text-primary);
	}

	.icon {
		font-size: 18px;
		color: var(--text-muted);
		flex-shrink: 0;
		width: 24px;
		text-align: center;
	}

	.a {
		font-size: 15px;
		color: var(--text-secondary);
		line-height: 1.7;
		margin-top: 12px;
		padding-right: 32px;
	}

	@media (max-width: 640px) {
		.faq { padding: 60px 16px; }
	}
</style>
