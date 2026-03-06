<script lang="ts">
	const steps = [
		{ num: '1', title: 'Download CashState', desc: 'Install free from the App Store. Takes seconds.' },
		{ num: '2', title: 'Connect your accounts', desc: 'Link your banks securely with read-only access.' },
		{ num: '3', title: 'Know your state', desc: 'Net worth, budgets, goals — synced and updated automatically.' },
	];
</script>

<section class="how" id="how-it-works">
	<div class="inner">
		<h2>Three steps. That's it.</h2>
		<div class="steps">
			{#each steps as step}
				<div class="step">
					<span class="num">{step.num}</span>
					<div>
						<h3>{step.title}</h3>
						<p>{step.desc}</p>
					</div>
				</div>
			{/each}
		</div>
	</div>
</section>

<style>
	.how {
		padding: 100px 24px;
		background: var(--bg-alt);
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

	.steps {
		display: flex;
		flex-direction: column;
	}

	.step {
		display: flex;
		align-items: flex-start;
		gap: 20px;
		padding: 24px 0;
		border-top: 1px solid var(--border);
	}

	.step:last-child {
		border-bottom: 1px solid var(--border);
	}

	.num {
		font-size: 14px;
		font-weight: 700;
		color: var(--accent);
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border: 2px solid var(--accent);
		border-radius: 10px;
		flex-shrink: 0;
	}

	h3 {
		font-size: 17px;
		font-weight: 600;
		color: var(--text-primary);
		margin-bottom: 4px;
	}

	.step p {
		font-size: 15px;
		color: var(--text-secondary);
		line-height: 1.5;
	}

	@media (max-width: 640px) {
		.how { padding: 60px 16px; }
	}
</style>
