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
			<button class="nav-btn" onclick={prev} aria-label="Previous">
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
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
						style="transform: translateX(calc({offset} * (100% + 24px))) scale({isActive ? 1 : 0.88}); opacity: {isVisible ? (isActive ? 1 : 0.4) : 0}; z-index: {isActive ? 2 : 1};"
						onclick={() => goTo(i)}
					>
						<img src={s.src} alt={s.label} />
						<span class="phone-label">{s.label}</span>
					</button>
				{/each}
			</div>

			<button class="nav-btn" onclick={next} aria-label="Next">
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
			</button>
		</div>

		<div class="dots">
			{#each screenshots as _, i}
				<button class="dot" class:active={current === i} onclick={() => goTo(i)} aria-label="Go to slide {i + 1}"></button>
			{/each}
		</div>

		<h2>Designed for clarity.</h2>
		<p class="sub">Personal finance, simplified. Every screen crafted to help you understand your finances at a glance.</p>
	</div>
</section>

<style>
	.showcase {
		padding: 40px 24px 120px;
		background: var(--bg);
	}

	.inner {
		max-width: 1100px;
		margin: 0 auto;
		text-align: center;
	}

	h2 {
		font-size: clamp(32px, 5vw, 48px);
		font-weight: 500;
		color: var(--text-primary);
		letter-spacing: -0.025em;
		line-height: 1.15;
		margin-top: 56px;
		margin-bottom: 16px;
	}

	.sub {
		font-size: 18px;
		font-weight: 400;
		color: var(--text-secondary);
		max-width: 480px;
		margin: 0 auto;
		line-height: 1.7;
	}

	.carousel-wrapper {
		display: flex;
		align-items: center;
		gap: 16px;
		margin-bottom: 36px;
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
		border-radius: 36px;
		padding: 6px;
		box-shadow: 0 20px 60px -12px rgba(0,0,0,0.25);
		transition: transform 0.5s cubic-bezier(0.4, 0, 0.2, 1), opacity 0.5s ease, box-shadow 0.5s ease;
		cursor: pointer;
		text-align: center;
	}

	.phone.active {
		box-shadow: 0 32px 80px -16px rgba(0,0,0,0.35);
	}

	.phone.hidden {
		pointer-events: none;
	}

	.phone img {
		width: 100%;
		border-radius: 30px;
		aspect-ratio: 9 / 19.5;
		object-fit: cover;
		object-position: top;
	}

	.phone-label {
		display: block;
		font-size: 13px;
		font-weight: 600;
		color: rgba(255,255,255,0.4);
		padding: 10px 0 6px;
		letter-spacing: 0.02em;
		transition: color 0.3s;
	}

	.phone.active .phone-label {
		color: rgba(255,255,255,0.9);
	}

	.nav-btn {
		flex: 0 0 auto;
		width: 48px;
		height: 48px;
		border-radius: 50%;
		background: var(--card-bg);
		border: 1px solid var(--border);
		display: flex;
		align-items: center;
		justify-content: center;
		color: var(--text-secondary);
		transition: all 0.2s;
		z-index: 2;
	}

	.nav-btn:hover {
		color: var(--text-primary);
		border-color: var(--text-muted);
		transform: scale(1.05);
	}

	.dots {
		display: flex;
		gap: 8px;
		justify-content: center;
	}

	.dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		background: var(--border);
		transition: all 0.3s;
	}

	.dot.active {
		background: var(--accent);
		width: 28px;
		border-radius: 4px;
	}

	@media (max-width: 640px) {
		.showcase { padding: 20px 20px 80px; }
		.carousel-viewport { height: 440px; }
		.nav-btn { display: none; }
		.carousel-wrapper { gap: 0; }
	}
</style>
