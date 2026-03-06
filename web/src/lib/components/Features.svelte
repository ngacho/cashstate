<script lang="ts">
	import { onMount, onDestroy } from 'svelte';

	const features = [
		{ icon: '📊', title: 'Net Worth Tracking', desc: 'All your accounts. One number. Updated automatically.' },
		{ icon: '💡', title: 'Smart Budgets', desc: 'AI-powered budgets that adapt to how you spend.' },
		{ icon: '🎯', title: 'Goal Progress', desc: 'Debt payoff, savings targets — tracked visually.' },
		{ icon: '🏷️', title: 'AI Categorization', desc: 'Transactions sorted intelligently. No manual work.' },
		{ icon: '📈', title: 'Spending Insights', desc: 'Month-over-month. Category by category.' },
		{ icon: '🔒', title: 'Read-Only Security', desc: 'Nobody can touch your money. Ever.' },
	];

	let current = $state(0);
	let interval: ReturnType<typeof setInterval>;

	const visibleCount = 3;

	function goTo(i: number) {
		if (i === current) return;
		clearInterval(interval);
		current = i;
		startAutoplay();
	}

	function prev() {
		goTo((current - 1 + features.length) % features.length);
	}

	function next() {
		goTo((current + 1) % features.length);
	}

	function getOffset(i: number): number {
		let diff = i - current;
		if (diff > features.length / 2) diff -= features.length;
		if (diff < -features.length / 2) diff += features.length;
		return diff;
	}

	function startAutoplay() {
		interval = setInterval(() => next(), 3000);
	}

	onMount(() => { startAutoplay(); });
	onDestroy(() => { if (interval) clearInterval(interval); });
</script>

<section class="features" id="features">
	<div class="header">
		<h2>Everything you need.<br />Nothing you don't.</h2>
		<p class="sub">Powerful features wrapped in an interface so intuitive, you'll wonder how you ever managed without it.</p>
	</div>

	<div class="carousel-wrapper">
		<button class="nav-btn" onclick={prev} aria-label="Previous">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
		</button>

		<div class="carousel-viewport">
			{#each features as f, i}
				{@const offset = getOffset(i)}
				{@const isVisible = Math.abs(offset) <= 1}
				{@const isActive = offset === 0}
				<div
					class="card"
					class:active={isActive}
					style="transform: translateX(calc({offset} * (100% + 20px))); opacity: {isVisible ? (isActive ? 1 : 0.5) : 0}; pointer-events: {isVisible ? 'auto' : 'none'};"
					role="button"
					tabindex="0"
					onclick={() => goTo(i)}
					onkeydown={(e) => { if (e.key === 'Enter') goTo(i); }}
				>
					<div class="icon-wrap">
						<span class="icon">{f.icon}</span>
					</div>
					<h3>{f.title}</h3>
					<p>{f.desc}</p>
				</div>
			{/each}
		</div>

		<button class="nav-btn" onclick={next} aria-label="Next">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
		</button>
	</div>

	<div class="dots">
		{#each features as _, i}
			<button class="dot" class:active={current === i} onclick={() => goTo(i)}></button>
		{/each}
	</div>
</section>

<style>
	.features {
		padding: 100px 24px;
	}

	.header {
		text-align: center;
		margin-bottom: 56px;
	}

	h2 {
		font-size: clamp(36px, 5vw, 56px);
		font-weight: 700;
		color: var(--text-primary);
		letter-spacing: -0.03em;
		line-height: 1.1;
		margin-bottom: 16px;
	}

	.sub {
		font-size: 18px;
		color: var(--text-secondary);
		max-width: 560px;
		margin: 0 auto;
	}

	.carousel-wrapper {
		display: flex;
		align-items: center;
		gap: 16px;
		max-width: 1100px;
		margin: 0 auto;
	}

	.carousel-viewport {
		flex: 1;
		position: relative;
		height: 280px;
		overflow: hidden;
	}

	.card {
		position: absolute;
		left: 50%;
		top: 0;
		width: calc((100% - 40px) / 3);
		margin-left: calc(-1 * (100% - 40px) / 6);
		height: 100%;
		background: var(--bg-alt);
		border-radius: 24px;
		padding: 40px;
		transition: transform 0.5s cubic-bezier(0.4, 0, 0.2, 1), opacity 0.5s ease;
		cursor: pointer;
		display: flex;
		flex-direction: column;
		justify-content: flex-start;
	}

	.card.active {
		border: 1px solid var(--accent);
	}

	.icon-wrap {
		width: 48px;
		height: 48px;
		border-radius: 14px;
		background: var(--bg);
		display: flex;
		align-items: center;
		justify-content: center;
		margin-bottom: 20px;
	}

	.icon {
		font-size: 24px;
	}

	h3 {
		font-size: 22px;
		font-weight: 600;
		color: var(--text-primary);
		margin-bottom: 10px;
	}

	.card p {
		font-size: 16px;
		color: var(--text-secondary);
		line-height: 1.6;
	}

	.nav-btn {
		flex: 0 0 auto;
		width: 44px;
		height: 44px;
		border-radius: 50%;
		background: var(--card-bg);
		border: 1px solid var(--card-border);
		display: flex;
		align-items: center;
		justify-content: center;
		color: var(--text-primary);
		transition: background 0.2s, transform 0.2s;
	}

	.nav-btn:hover {
		background: var(--bg-alt);
		transform: scale(1.05);
	}

	.dots {
		display: flex;
		justify-content: center;
		gap: 8px;
		margin-top: 32px;
	}

	.dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		background: var(--text-muted);
		transition: all 0.3s;
	}

	.dot.active {
		background: var(--accent);
		width: 24px;
		border-radius: 4px;
	}

	@media (max-width: 640px) {
		.features { padding: 60px 16px; }
		.carousel-viewport { height: 200px; }
		.nav-btn { display: none; }
		.carousel-wrapper { gap: 0; }
	}
</style>
