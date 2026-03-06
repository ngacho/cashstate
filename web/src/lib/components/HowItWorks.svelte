<script lang="ts">
	const steps = [
		{ num: '1', title: 'Download CashState', desc: 'Install free from the App Store. Takes seconds.' },
		{ num: '2', title: 'Connect your accounts', desc: 'Link your banks securely with read-only access via SimpleFIN.' },
		{ num: '3', title: 'Know your state', desc: 'Net worth, budgets, goals — synced and updated automatically.' },
	];
</script>

<section class="how" id="how-it-works">
	<div class="inner">
		<div class="label">How it works</div>
		<h2>Three steps. That's it.</h2>
		<div class="steps">
			{#each steps as step, i}
				<div class="step">
					<div class="num-wrap">
						<span class="num">{step.num}</span>
						{#if i < steps.length - 1}
							<div class="connector"></div>
						{/if}
					</div>
					<div class="content">
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
		padding: 120px 24px;
		background: var(--bg-alt);
	}

	.inner {
		max-width: 600px;
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
		margin-bottom: 56px;
	}

	.steps {
		display: flex;
		flex-direction: column;
		text-align: left;
	}

	.step {
		display: flex;
		gap: 24px;
	}

	.num-wrap {
		display: flex;
		flex-direction: column;
		align-items: center;
		flex-shrink: 0;
	}

	.num {
		width: 48px;
		height: 48px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: var(--accent);
		color: #fff;
		border-radius: 50%;
		font-family: var(--font-serif);
		font-size: 20px;
		flex-shrink: 0;
	}

	.connector {
		width: 2px;
		flex: 1;
		background: var(--border);
		margin: 8px 0;
	}

	.content {
		padding: 8px 0 40px;
	}

	.step:last-child .content {
		padding-bottom: 0;
	}

	h3 {
		font-family: var(--font-serif);
		font-size: 20px;
		font-weight: 400;
		color: var(--text-primary);
		margin-bottom: 6px;
	}

	.step p {
		font-size: 15px;
		color: var(--text-secondary);
		line-height: 1.7;
	}

	@media (max-width: 640px) {
		.how { padding: 80px 20px; }
		.num { width: 40px; height: 40px; font-size: 18px; }
		.step { gap: 16px; }
	}
</style>
