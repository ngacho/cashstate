<script lang="ts">
	const steps = [
		{
			number: '01',
			title: 'Connect Your Accounts',
			description: 'Securely link your bank accounts, credit cards, and investment accounts in seconds.',
		},
		{
			number: '02',
			title: 'AI Analyzes Your Money',
			description: 'Our AI categorizes transactions, identifies patterns, and builds your financial picture.',
		},
		{
			number: '03',
			title: 'Know Your Cash State',
			description: 'Get real-time insights into your net worth, spending, budgets, and progress toward goals.',
		},
	];
</script>

<section class="how-it-works" id="how-it-works">
	<div class="inner">
		<div class="section-header">
			<span class="section-pill">How it works</span>
			<h2>Get started in minutes</h2>
			<p>Three simple steps to complete financial clarity.</p>
		</div>

		<div class="steps">
			{#each steps as step, i}
				<div class="step">
					<div class="step-number">{step.number}</div>
					<h3>{step.title}</h3>
					<p>{step.description}</p>
				</div>
				{#if i < steps.length - 1}
					<div class="step-connector">
						<svg width="40" height="2" viewBox="0 0 40 2">
							<line x1="0" y1="1" x2="40" y2="1" stroke="var(--color-border)" stroke-width="2" stroke-dasharray="4 4"/>
						</svg>
					</div>
				{/if}
			{/each}
		</div>
	</div>
</section>

<style>
	.how-it-works {
		padding: 6rem 2rem;
	}

	.inner {
		max-width: 1000px;
		margin: 0 auto;
	}

	.section-header {
		text-align: center;
		margin-bottom: 4rem;
	}

	.section-pill {
		display: inline-block;
		padding: 0.4rem 1rem;
		background: var(--color-accent-light);
		color: var(--color-accent);
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

	.steps {
		display: flex;
		align-items: flex-start;
		justify-content: center;
		gap: 1rem;
	}

	.step {
		flex: 1;
		text-align: center;
		max-width: 280px;
	}

	.step-number {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 56px;
		height: 56px;
		background: var(--color-primary);
		color: var(--color-white);
		border-radius: 16px;
		font-size: 1.2rem;
		font-weight: 800;
		margin-bottom: 1.2rem;
	}

	.step h3 {
		font-size: 1.1rem;
		font-weight: 700;
		color: var(--color-dark);
		margin-bottom: 0.5rem;
	}

	.step p {
		font-size: 0.9rem;
		color: var(--color-text);
		line-height: 1.6;
	}

	.step-connector {
		display: flex;
		align-items: center;
		padding-top: 1.8rem;
	}

	@media (max-width: 768px) {
		.steps {
			flex-direction: column;
			align-items: center;
		}

		.step-connector {
			transform: rotate(90deg);
			padding-top: 0;
		}
	}
</style>
