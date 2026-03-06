<script lang="ts">
	const features = [
		{
			icon: 'chart',
			title: 'Real-time Net Worth',
			description: 'Track all your accounts in one place and watch your net worth grow over time.',
			color: 'var(--color-primary)',
			bg: 'var(--color-primary-light)',
		},
		{
			icon: 'target',
			title: 'Financial Goals',
			description: 'Set savings goals and track your progress with smart milestones and projections.',
			color: 'var(--color-accent)',
			bg: 'var(--color-accent-light)',
		},
		{
			icon: 'wallet',
			title: 'Smart Budgets',
			description: 'AI-powered budgets that adapt to your spending patterns and help you save more.',
			color: 'var(--color-highlight)',
			bg: 'var(--color-highlight-light)',
		},
		{
			icon: 'zap',
			title: 'AI Categorization',
			description: 'Transactions are automatically categorized using intelligent pattern recognition.',
			color: 'var(--color-primary)',
			bg: 'var(--color-primary-light)',
		},
		{
			icon: 'shield',
			title: 'Bank-Level Security',
			description: 'Your data is encrypted end-to-end. We never store your bank credentials.',
			color: 'var(--color-accent)',
			bg: 'var(--color-accent-light)',
		},
		{
			icon: 'sync',
			title: 'Auto Sync',
			description: 'Connect your bank accounts and transactions sync automatically every day.',
			color: 'var(--color-highlight)',
			bg: 'var(--color-highlight-light)',
		},
	];
</script>

<section class="features" id="features">
	<div class="features-inner">
		<div class="section-header">
			<span class="section-pill">Features</span>
			<h2>Everything you need to<br/>master your finances</h2>
			<p>Powerful tools that give you complete visibility and control over your money.</p>
		</div>

		<div class="features-grid">
			{#each features as feature}
				<div class="feature-card">
					<div class="feature-icon" style="background: {feature.bg}; color: {feature.color};">
						{#if feature.icon === 'chart'}
							<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"></polyline></svg>
						{:else if feature.icon === 'target'}
							<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><circle cx="12" cy="12" r="6"></circle><circle cx="12" cy="12" r="2"></circle></svg>
						{:else if feature.icon === 'wallet'}
							<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"></rect><line x1="1" y1="10" x2="23" y2="10"></line></svg>
						{:else if feature.icon === 'zap'}
							<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon></svg>
						{:else if feature.icon === 'shield'}
							<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>
						{:else if feature.icon === 'sync'}
							<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="23 4 23 10 17 10"></polyline><polyline points="1 20 1 14 7 14"></polyline><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"></path></svg>
						{/if}
					</div>
					<h3>{feature.title}</h3>
					<p>{feature.description}</p>
				</div>
			{/each}
		</div>
	</div>
</section>

<style>
	.features {
		padding: 6rem 2rem;
		background: var(--color-background);
	}

	.features-inner {
		max-width: 1100px;
		margin: 0 auto;
	}

	.section-header {
		text-align: center;
		margin-bottom: 4rem;
	}

	.section-pill {
		display: inline-block;
		padding: 0.4rem 1rem;
		background: var(--color-primary-light);
		color: var(--color-primary);
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
		max-width: 500px;
		margin: 0 auto;
	}

	.features-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 1.5rem;
	}

	.feature-card {
		background: var(--color-white);
		border-radius: 20px;
		padding: 2rem;
		border: 1px solid var(--color-border);
		transition: all 0.3s ease;
	}

	.feature-card:hover {
		transform: translateY(-4px);
		box-shadow: 0 12px 40px rgba(0, 0, 0, 0.08);
	}

	.feature-icon {
		width: 48px;
		height: 48px;
		border-radius: 14px;
		display: flex;
		align-items: center;
		justify-content: center;
		margin-bottom: 1.2rem;
	}

	.feature-card h3 {
		font-size: 1.1rem;
		font-weight: 700;
		color: var(--color-dark);
		margin-bottom: 0.5rem;
	}

	.feature-card p {
		font-size: 0.9rem;
		color: var(--color-text);
		line-height: 1.6;
	}

	@media (max-width: 768px) {
		.features-grid {
			grid-template-columns: 1fr;
		}
	}

	@media (min-width: 769px) and (max-width: 1024px) {
		.features-grid {
			grid-template-columns: repeat(2, 1fr);
		}
	}
</style>
