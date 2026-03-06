<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { carouselItems, carouselIndex } from '$lib/theme.svelte';

	const screenshots = [
		{ src: '/screenshots/home-view.png', label: 'Net Worth', wordIndex: 1 },
		{ src: '/screenshots/account-details.PNG', label: 'Accounts', wordIndex: 0 },
		{ src: '/screenshots/spending.PNG', label: 'Budget', wordIndex: 2 },
		{ src: '/screenshots/spending-compare.PNG', label: 'Spending', wordIndex: 3 },
		{ src: '/screenshots/buget-set.PNG', label: 'Categories', wordIndex: 2 },
		{ src: '/screenshots/debt-goal.PNG', label: 'Goals', wordIndex: 4 },
	];

	let current = $state(0);
	let interval: ReturnType<typeof setInterval>;

	function goTo(i: number) {
		if (i === current) return;
		clearInterval(interval);
		current = i;
		carouselIndex.value = screenshots[i].wordIndex;
		startAutoplay();
	}

	function prev() {
		goTo((current - 1 + screenshots.length) % screenshots.length);
	}

	function next() {
		goTo((current + 1) % screenshots.length);
	}

	function startAutoplay() {
		interval = setInterval(() => next(), 3500);
	}

	function getOffset(i: number): number {
		const diff = i - current;
		// Handle wrapping for smooth circular feel
		if (diff > screenshots.length / 2) return diff - screenshots.length;
		if (diff < -screenshots.length / 2) return diff + screenshots.length;
		return diff;
	}

	onMount(() => {
		carouselIndex.value = screenshots[0].wordIndex;
		startAutoplay();
	});

	onDestroy(() => { if (interval) clearInterval(interval); });
</script>

<section class="showcase">
	<div class="inner">
		<div class="carousel-wrapper">
			<button class="nav-btn nav-prev" onclick={prev} aria-label="Previous">
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
			</button>

			<div class="carousel-viewport">
				{#each screenshots as s, i}
					{@const offset = getOffset(i)}
					{@const isVisible = Math.abs(offset) <= 1}
					{@const isActive = offset === 0}
					<button
						class="phone"
						class:active={isActive}
						class:hidden={!isVisible}
						style="transform: translateX(calc({offset} * (100% + 24px))) scale({isActive ? 1 : 0.85}); opacity: {isVisible ? (isActive ? 1 : 0.55) : 0}; z-index: {isActive ? 2 : 1};"
						onclick={() => goTo(i)}
					>
						<img src={s.src} alt={s.label} />
						<span class="phone-label">{s.label}</span>
					</button>
				{/each}
			</div>

			<button class="nav-btn nav-next" onclick={next} aria-label="Next">
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
			</button>
		</div>

		<div class="dots">
			{#each screenshots as _, i}
				<button class="dot" class:active={current === i} onclick={() => goTo(i)}></button>
			{/each}
		</div>

		<h2>Designed for clarity.</h2>
		<p class="sub">Every screen crafted to help you understand your finances at a glance.</p>

		<a href="/app-store" class="btn-download">
			Download for free
			<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
		</a>
	</div>
</section>

<style>
	.showcase {
		padding: 0 24px 100px;
		background: var(--bg);
	}

	.inner {
		max-width: 1100px;
		margin: 0 auto;
		text-align: center;
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
		max-width: 500px;
		margin: 0 auto 32px;
	}

	h2 {
		margin-top: 48px;
	}

	.carousel-wrapper {
		display: flex;
		align-items: center;
		gap: 12px;
		margin-bottom: 32px;
	}

	.carousel-viewport {
		flex: 1;
		position: relative;
		height: 580px;
		overflow: hidden;
	}

	.phone {
		position: absolute;
		left: 50%;
		top: 0;
		width: calc((100% - 48px) / 3);
		margin-left: calc(-1 * (100% - 48px) / 6);
		background: #000;
		border-radius: 32px;
		padding: 6px;
		box-shadow: 0 16px 48px -12px rgba(0,0,0,0.2);
		transition: transform 0.5s cubic-bezier(0.4, 0, 0.2, 1), opacity 0.5s ease, box-shadow 0.5s ease;
		cursor: pointer;
		text-align: center;
	}

	.phone.active {
		box-shadow: 0 32px 64px -16px rgba(0,0,0,0.35);
	}

	.phone.hidden {
		pointer-events: none;
	}

	.phone img {
		width: 100%;
		border-radius: 27px;
		aspect-ratio: 9 / 19.5;
		object-fit: cover;
		object-position: top;
	}

	.phone-label {
		display: block;
		font-size: 13px;
		font-weight: 600;
		color: rgba(255,255,255,0.5);
		padding: 8px 0 4px;
		transition: color 0.3s;
	}

	.phone.active .phone-label {
		color: rgba(255,255,255,0.9);
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
		z-index: 2;
	}

	.nav-btn:hover {
		background: var(--bg-alt);
		transform: scale(1.05);
	}

	.dots {
		display: flex;
		gap: 8px;
		justify-content: center;
		margin-bottom: 32px;
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

	.btn-download {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 14px 28px;
		background: var(--text-primary);
		color: var(--bg);
		border-radius: 100px;
		font-size: 15px;
		font-weight: 600;
		transition: opacity 0.2s;
	}

	.btn-download:hover { opacity: 0.85; }

	@media (max-width: 640px) {
		.showcase { padding: 60px 16px; }
		.carousel-viewport { height: 440px; }
		.nav-btn { display: none; }
		.carousel-wrapper { gap: 0; }
	}
</style>
