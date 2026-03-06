<script lang="ts">
	import RotatingText from './RotatingText.svelte';
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

<section class="hero">
	<div class="hero-inner">
		<div class="pill">
			<svg width="16" height="16" viewBox="0 0 16 16" fill="none">
				<path d="M8 2l1.5 3 3.5.5-2.5 2.5.5 3.5L8 10l-3 1.5.5-3.5L3 5.5 6.5 5z" fill="var(--color-primary)"/>
			</svg>
			Intelligence for every transaction
		</div>

		<h1>
			Master Your <span class="highlight-money">Money</span> with<br/>
			Intelligent <span class="highlight-clarity">Clarity</span>
		</h1>

		<p class="subtitle">
			Know <RotatingText /> — CashState helps you visualize your income,
			expenses, and savings in real time, powered by AI insights.
		</p>

		<div class="cta-group">
			<a href="#get-started" class="btn-primary">
				Get Started
				<svg width="18" height="18" viewBox="0 0 16 16" fill="none">
					<path d="M3 8h10M9 4l4 4-4 4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
				</svg>
			</a>
			<a href="#faq" class="btn-secondary">
				Learn More
				<svg width="18" height="18" viewBox="0 0 16 16" fill="none">
					<path d="M3 8h10M9 4l4 4-4 4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
				</svg>
			</a>
		</div>
	</div>

	<div class="hero-visual">
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
</section>

<style>
	.hero {
		min-height: 100vh;
		padding: 8rem 2rem 4rem;
		text-align: center;
		position: relative;
		overflow: hidden;
		background: radial-gradient(ellipse at 50% 0%, var(--color-primary-light) 0%, transparent 60%);
	}

	.hero-inner {
		max-width: 800px;
		margin: 0 auto;
		position: relative;
		z-index: 2;
	}

	.pill {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1.2rem;
		background: var(--color-white);
		border: 1px solid var(--color-border);
		border-radius: 100px;
		font-size: 0.9rem;
		font-weight: 500;
		color: var(--color-primary);
		margin-bottom: 2rem;
	}

	h1 {
		font-size: clamp(2.5rem, 6vw, 4rem);
		font-weight: 900;
		line-height: 1.1;
		color: var(--color-dark);
		margin-bottom: 1.5rem;
		letter-spacing: -0.02em;
	}

	.highlight-money {
		color: var(--color-primary);
	}

	.highlight-clarity {
		color: var(--color-accent);
	}

	.subtitle {
		font-size: 1.15rem;
		color: var(--color-text);
		max-width: 600px;
		margin: 0 auto 2.5rem;
		line-height: 1.7;
	}

	.cta-group {
		display: flex;
		gap: 1rem;
		justify-content: center;
		flex-wrap: wrap;
	}

	.btn-primary {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.9rem 2rem;
		background: var(--color-primary);
		color: white;
		border-radius: 100px;
		font-size: 1rem;
		font-weight: 600;
		transition: all 0.2s;
		box-shadow: 0 4px 14px rgba(13, 148, 136, 0.35);
	}

	.btn-primary:hover {
		background: var(--color-primary-dark);
		transform: translateY(-1px);
		box-shadow: 0 6px 20px rgba(13, 148, 136, 0.4);
	}

	.btn-secondary {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.9rem 2rem;
		background: var(--color-white);
		color: var(--color-dark);
		border: 1.5px solid var(--color-border);
		border-radius: 100px;
		font-size: 1rem;
		font-weight: 600;
		transition: all 0.2s;
	}

	.btn-secondary:hover {
		border-color: var(--color-primary);
		color: var(--color-primary);
	}

	/* Phone mockup with real screenshots */
	.hero-visual {
		position: relative;
		max-width: 900px;
		margin: 4rem auto 0;
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
		position: absolute;
		bottom: 0;
		left: 50%;
		transform: translateX(-50%);
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
		background: var(--color-white);
		border-radius: 16px;
		padding: 1rem 1.2rem;
		box-shadow: 0 8px 30px rgba(0, 0, 0, 0.08);
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
		.hero {
			padding: 6rem 1.5rem 2rem;
		}

		.hero-visual {
			height: 500px;
			margin-top: 2rem;
		}

		.floating-card {
			display: none;
		}

		.phone-mockup {
			width: 240px;
		}
	}
</style>
