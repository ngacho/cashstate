<script lang="ts">
	import { onMount, onDestroy } from 'svelte';

	const screenshots = [
		{ src: '/screenshots/home-view.png', alt: 'Home view with net worth and accounts' },
		{ src: '/screenshots/account-details.PNG', alt: 'Account details with balance chart' },
		{ src: '/screenshots/spending.PNG', alt: 'Budget overview with spending categories' },
		{ src: '/screenshots/spending-compare.PNG', alt: 'Month-over-month spending comparison' },
		{ src: '/screenshots/buget-set.PNG', alt: 'Budget setup with linked accounts' },
		{ src: '/screenshots/debt-goal.PNG', alt: 'Debt payoff goal tracking' },
	];

	let currentScreenshot = $state(0);
	let isTransitioning = $state(false);
	let interval: ReturnType<typeof setInterval>;

	function goTo(index: number) {
		if (index === currentScreenshot || isTransitioning) return;
		isTransitioning = true;
		setTimeout(() => {
			currentScreenshot = index;
			isTransitioning = false;
		}, 300);
	}

	onMount(() => {
		interval = setInterval(() => {
			const next = (currentScreenshot + 1) % screenshots.length;
			goTo(next);
		}, 4000);
	});

	onDestroy(() => {
		if (interval) clearInterval(interval);
	});
</script>

<section class="showcase">
	<div class="showcase-inner">
		<div class="phone-mockup">
			<div class="phone-notch"></div>
			<div class="phone-screen">
				<img
					src={screenshots[currentScreenshot].src}
					alt={screenshots[currentScreenshot].alt}
					class="screenshot"
					class:transitioning={isTransitioning}
				/>
			</div>
		</div>

		<div class="floating-card card-savings">
			<div class="card-icon savings-icon">
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<polyline points="23 6 13.5 15.5 8.5 10.5 1 18"></polyline>
					<polyline points="17 6 23 6 23 12"></polyline>
				</svg>
			</div>
			<div class="card-value">$2.4K</div>
			<div class="card-label">Saved this month</div>
		</div>

		<div class="floating-card card-income">
			<div class="card-icon income-icon">
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<line x1="12" y1="1" x2="12" y2="23"></line>
					<path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"></path>
				</svg>
			</div>
			<div class="card-value">+35%</div>
			<div class="card-label">Income growth</div>
		</div>

		<div class="floating-card card-goal">
			<div class="card-icon goal-icon">
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<circle cx="12" cy="12" r="10"></circle>
					<circle cx="12" cy="12" r="6"></circle>
					<circle cx="12" cy="12" r="2"></circle>
				</svg>
			</div>
			<div class="card-value">78%</div>
			<div class="card-label">Goal progress</div>
		</div>
	</div>

	<div class="carousel-dots">
		{#each screenshots as _, i}
			<button
				class="dot"
				class:active={currentScreenshot === i}
				onclick={() => goTo(i)}
				aria-label="Show screenshot {i + 1}"
			></button>
		{/each}
	</div>
</section>

<style>
	.showcase {
		padding: 0 2rem 6rem;
		text-align: center;
		background: var(--color-white);
		overflow: hidden;
	}

	.showcase-inner {
		position: relative;
		max-width: 900px;
		margin: 0 auto;
		height: 580px;
	}

	.phone-mockup {
		position: absolute;
		left: 50%;
		top: 50%;
		transform: translate(-50%, -50%);
		width: 280px;
		background: #000;
		border-radius: 40px;
		padding: 8px;
		box-shadow:
			0 25px 60px rgba(0, 0, 0, 0.2),
			0 0 0 1px rgba(255, 255, 255, 0.1) inset;
	}

	.phone-notch {
		width: 120px;
		height: 28px;
		background: #000;
		border-radius: 0 0 18px 18px;
		margin: 0 auto;
		position: relative;
		z-index: 3;
		margin-top: -2px;
	}

	.phone-screen {
		background: #1a1a1a;
		border-radius: 34px;
		overflow: hidden;
		aspect-ratio: 9 / 19.5;
		position: relative;
		margin-top: -14px;
	}

	.screenshot {
		width: 100%;
		height: 100%;
		object-fit: cover;
		object-position: top;
		transition: opacity 0.3s ease;
	}

	.screenshot.transitioning {
		opacity: 0;
	}

	.carousel-dots {
		display: flex;
		justify-content: center;
		gap: 0.5rem;
		margin-top: 1.5rem;
	}

	.dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		background: var(--color-border);
		padding: 0;
		transition: all 0.3s;
	}

	.dot.active {
		background: var(--color-primary);
		width: 24px;
		border-radius: 4px;
	}

	/* Floating stat cards */
	.floating-card {
		position: absolute;
		background: var(--color-card);
		border-radius: 16px;
		padding: 1rem 1.2rem;
		box-shadow: 0 8px 30px rgba(0, 0, 0, 0.3);
		border: 1px solid var(--color-border);
		text-align: left;
		animation: float 6s ease-in-out infinite;
	}

	.card-icon {
		width: 36px;
		height: 36px;
		border-radius: 10px;
		display: flex;
		align-items: center;
		justify-content: center;
		margin-bottom: 0.5rem;
	}

	.savings-icon {
		background: var(--color-primary-light);
		color: var(--color-primary);
	}

	.income-icon {
		background: var(--color-highlight-light);
		color: var(--color-highlight);
	}

	.goal-icon {
		background: var(--color-accent-light);
		color: var(--color-accent);
	}

	.card-value {
		font-size: 1.3rem;
		font-weight: 800;
		color: var(--color-dark);
	}

	.card-label {
		font-size: 0.75rem;
		color: var(--color-text-light);
		margin-top: 0.15rem;
	}

	.card-savings {
		top: 8%;
		left: 2%;
		animation-delay: 0s;
	}

	.card-income {
		bottom: 12%;
		left: 5%;
		animation-delay: -2s;
	}

	.card-goal {
		top: 15%;
		right: 2%;
		animation-delay: -4s;
	}

	@keyframes float {
		0%, 100% { transform: translateY(0px); }
		50% { transform: translateY(-12px); }
	}

	@media (max-width: 768px) {
		.showcase-inner {
			height: 500px;
		}

		.floating-card {
			display: none;
		}

		.phone-mockup {
			width: 240px;
		}
	}
</style>
