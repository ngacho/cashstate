<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import lottie from 'lottie-web';

	const features = [
		{ lottie: '/lottie/chart/Man_with_Graphs.json', title: 'Net Worth Tracking', desc: 'All your accounts. One number. Updated automatically.' },
		{ lottie: '/lottie/budget/Wallet_animation.json', title: 'Smart Budgets', desc: 'AI-powered budgets that adapt to how you spend.' },
		{ lottie: '/lottie/goal/Target.json', title: 'Goal Progress', desc: 'Debt payoff, savings targets — tracked visually.' },
		{ inlineSvg: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><g fill="currentColor"><path d="M328.021,1c-99.08,0-181.029,80.143-182.984,179.311c-0.536,27.195,4.758,53.47,15.736,78.096c6.364,14.276,3.17,31.338-7.947,42.456l-5.281,5.281c-1.953,1.952-1.953,5.119,0,7.071l3.2,3.2l-28.705,28.719l-9.053-9.053c-1.951-1.953-5.12-1.953-7.071,0l-94.202,94.202c-14.286,14.285-14.286,37.527,0,51.812l18.191,18.191c14.285,14.286,37.527,14.285,51.812,0l94.202-94.202c1.953-1.952,1.953-5.119,0-7.071l-9.037-9.037l28.705-28.72l3.198,3.198c1.951,1.953,5.12,1.953,7.071,0l5.281-5.281c11.119-11.117,28.182-14.311,42.456-7.947c24.009,10.703,50.195,16.281,78.094,15.736c99.648-1.964,180.084-84.694,179.307-184.419C510.211,82.099,428.664,1,328.021,1z M74.646,493.215c-10.407,10.407-27.259,10.41-37.67,0l-18.191-18.191c-10.407-10.407-10.41-27.26,0-37.67l44.688-44.687l55.861,55.86L74.646,493.215z M143.906,423.954l-55.86-55.86l21.406-21.405c62.86,62.861,20.025,20.025,55.86,55.86L143.906,423.954z M331.49,356.964c-25.726,0.505-50.551-4.497-73.824-14.871c-18.256-8.138-39.747-3.843-53.6,10.01l-1.745,1.744l-44.168-44.168l1.744-1.745c14.027-14.026,18.05-35.567,10.01-53.6c-10.374-23.272-15.378-48.111-14.871-73.826c1.858-94.213,80.154-170.32,174.344-169.501c93.896,0.733,170.881,77.72,171.613,171.616C501.729,276.899,425.69,355.107,331.49,356.964z"/><path d="m439.173 101.408 1.804-22.236c.252-3.092-2.34-5.642-5.387-5.389l-21.492 1.74c-24.378-19.369-54.867-30.019-86.096-30.019-76.94 0-138.503 62.455-138.503 138.494 0 77.525 63.663 140.076 141.408 138.466.026 0 .05.008.076.008.033 0 .064-.009.097-.01 74.684-1.638 135.416-62.853 135.416-138.464C466.496 153.922 457.051 125.411 439.173 101.408zM235.973 273.86c-10.986-11.295-19.992-24.742-26.385-39.914l26.385-26.385V273.86zM280.977 303.712c-12.741-4.966-24.54-11.939-35.003-20.614V197.56l34.103-34.103.9.9V303.712zM325.982 312.463c-12.092-.185-23.841-2.017-35.004-5.335V174.359c7.113 7.107 34.306 34.332 35.004 34.969V312.463zM370.986 305.097c-11.055 3.936-22.801 6.397-35.003 7.149V206.06l35.003-35.003V305.097zM415.991 277.553c-10.238 9.635-22.047 17.617-35.003 23.506V161.056l32.262-32.262 2.741 2.743V277.553zM426.952 128.357c-.346-.346-9.819-9.824-10.165-10.17-2.01-2.012-5.174-1.902-7.072-.001-17.933 17.932-64.795 64.794-80.383 80.382-5.921-5.921-38.007-38.007-45.719-45.718-1.951-1.953-5.12-1.953-7.071 0-9.605 9.605-59.394 59.394-70.8 70.8-4.458-13.748-6.621-28.329-6.181-43.423l77.617-77.616 57.31 57.309c1.953 1.955 5.123 1.95 7.071 0l54.945-54.946c1.953-1.952 1.953-5.119 0-7.071L386.4 87.8l44.132-3.574L426.952 128.357zM184.503 302.495c-1.951-1.953-5.12-1.953-7.071 0-1.953 1.952-1.953 5.119 0 7.071l25.002 25.002c1.951 1.953 5.12 1.953 7.071 0 1.953-1.952 1.953-5.119 0-7.071L184.503 302.495z"/></g></svg>`, title: 'Spending Insights', desc: 'Month-over-month. Category by category.' },
		{ lottie: '/lottie/security/Security.json', title: 'Read-Only Security', desc: 'Bank-level encryption. No one can move your money.' },
	];

	let current = $state(0);
	let interval: ReturnType<typeof setInterval>;
	let lottieContainers: HTMLDivElement[] = [];
	let animations: ReturnType<typeof lottie.loadAnimation>[] = [];

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

	onMount(() => {
		startAutoplay();

		for (let i = 0; i < features.length; i++) {
			if (features[i].lottie && lottieContainers[i]) {
				const anim = lottie.loadAnimation({
					container: lottieContainers[i],
					renderer: 'svg',
					loop: true,
					autoplay: true,
					path: features[i].lottie,
				});
				animations.push(anim);
			}
		}
	});

	onDestroy(() => {
		if (interval) clearInterval(interval);
		for (const anim of animations) {
			anim.destroy();
		}
	});
</script>

<section class="features" id="features">
	<div class="header">
		<div class="label">Features</div>
		<h2>Everything you need.<br />For free.</h2>
		<p class="sub">Powerful features wrapped in an interface so intuitive, you'll wonder how you ever managed without it.</p>
	</div>

	<div class="carousel-wrapper">
		<button class="nav-btn" onclick={prev} aria-label="Previous">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
		</button>

		<div class="carousel-viewport">
			{#each features as f, i}
				{@const offset = getOffset(i)}
				{@const isVisible = Math.abs(offset) <= 1}
				{@const isActive = offset === 0}
				<div
					class="card"
					class:active={isActive}
					style="transform: translateX(calc({offset} * (100% + 24px))); opacity: {isVisible ? (isActive ? 1 : 0.4) : 0}; pointer-events: {isVisible ? 'auto' : 'none'};"
					role="button"
					tabindex="0"
					onclick={() => goTo(i)}
					onkeydown={(e) => { if (e.key === 'Enter') goTo(i); }}
				>
					{#if f.inlineSvg}
					<div class="svg-wrap">
						{@html f.inlineSvg}
					</div>
				{:else}
					<div class="lottie-wrap" bind:this={lottieContainers[i]}></div>
				{/if}
					<h3>{f.title}</h3>
					<p>{f.desc}</p>
				</div>
			{/each}
		</div>

		<button class="nav-btn" onclick={next} aria-label="Next">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
		</button>
	</div>

	<div class="dots">
		{#each features as _, i}
			<button class="dot" class:active={current === i} onclick={() => goTo(i)} aria-label="Go to slide {i + 1}"></button>
		{/each}
	</div>
</section>

<style>
	.features {
		padding: 120px 24px;
	}

	.header {
		text-align: center;
		margin-bottom: 64px;
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
		font-size: clamp(32px, 5vw, 48px);
		font-weight: 500;
		color: var(--text-primary);
		letter-spacing: -0.025em;
		line-height: 1.15;
		margin-bottom: 20px;
	}

	.sub {
		font-size: 18px;
		font-weight: 400;
		color: var(--text-secondary);
		max-width: 520px;
		margin: 0 auto;
		line-height: 1.6;
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
		height: 340px;
		overflow: hidden;
	}

	.card {
		position: absolute;
		left: 50%;
		top: 0;
		width: calc((100% - 48px) / 3);
		margin-left: calc(-1 * (100% - 48px) / 6);
		height: 100%;
		background: var(--bg-alt);
		border: 1px solid var(--border);
		border-radius: 24px;
		padding: 32px;
		transition: transform 0.5s cubic-bezier(0.4, 0, 0.2, 1), opacity 0.5s ease, border-color 0.3s;
		cursor: pointer;
		display: flex;
		flex-direction: column;
		justify-content: flex-start;
		overflow: hidden;
	}

	.card.active {
		border-color: var(--accent);
	}

	.lottie-wrap {
		width: 80px;
		height: 80px;
		margin-bottom: 20px;
		flex-shrink: 0;
	}

	.svg-wrap {
		width: 64px;
		height: 64px;
		margin-bottom: 20px;
		flex-shrink: 0;
		color: var(--accent);
		animation: svg-pulse 3s ease-in-out infinite;
	}

	.svg-wrap :global(svg) {
		width: 100%;
		height: 100%;
	}

	@keyframes svg-pulse {
		0%, 100% { transform: scale(1); opacity: 0.85; }
		50% { transform: scale(1.08); opacity: 1; }
	}

	h3 {
		font-size: 20px;
		font-weight: 600;
		color: var(--text-primary);
		letter-spacing: -0.01em;
		margin-bottom: 10px;
	}

	.card p {
		font-size: 15px;
		color: var(--text-secondary);
		line-height: 1.7;
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
	}

	.nav-btn:hover {
		color: var(--text-primary);
		border-color: var(--text-muted);
		transform: scale(1.05);
	}

	.dots {
		display: flex;
		justify-content: center;
		gap: 8px;
		margin-top: 40px;
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
		.features { padding: 80px 20px; }
		.carousel-viewport { height: 280px; }
		.nav-btn { display: none; }
		.carousel-wrapper { gap: 0; }
	}
</style>
