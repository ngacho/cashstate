<script lang="ts">
	import RotatingText from './RotatingText.svelte';
	import appStoreLight from '$lib/assets/Download-AppStore.png';
	import appStoreDark from '$lib/assets/Download-AppStoreDark.png';
</script>

<section class="hero" id="hero">
	<div class="inner">
		<h1>
			Know the state<br />of your<br /><RotatingText />.
		</h1>
		<p class="subtitle">
			The effortless way to track spending, set budgets, and reach your financial goals.
			Beautiful, powerful, and completely free.
		</p>
		<div class="actions">
			<a href="/app-store" class="store-badge" aria-label="Download on the App Store">
				<img class="badge-light" src={appStoreLight} alt="Download on the App Store" />
				<img class="badge-dark" src={appStoreDark} alt="Download on the App Store" />
			</a>
			<a href="#features" class="btn-secondary">
				See features
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"/><polyline points="19 12 12 19 5 12"/></svg>
			</a>
		</div>
	</div>
	<div class="glow"></div>
</section>

<style>
	.hero {
		padding: 180px 24px 80px;
		text-align: center;
		position: relative;
		overflow: hidden;
	}

	.glow {
		position: absolute;
		top: -20%;
		left: 50%;
		transform: translateX(-50%);
		width: 700px;
		height: 700px;
		background: radial-gradient(circle, var(--accent-light) 0%, transparent 65%);
		pointer-events: none;
		z-index: 0;
	}

	.inner {
		max-width: 800px;
		margin: 0 auto;
		position: relative;
		z-index: 1;
	}

	.badge {
		display: inline-block;
		padding: 8px 20px;
		background: var(--accent-light);
		color: var(--accent);
		border-radius: 100px;
		font-size: 13px;
		font-weight: 600;
		letter-spacing: 0.04em;
		text-transform: uppercase;
		margin-bottom: 32px;
	}

	h1 {
		font-size: clamp(48px, 8vw, 60px);
		font-weight: 500;
		color: var(--text-primary);
		letter-spacing: -0.025em;
		line-height: 1.1;
		margin-bottom: 40px;
	}

	.subtitle {
		font-size: 20px;
		font-weight: 400;
		color: var(--text-secondary);
		line-height: 1.6;
		max-width: 540px;
		margin: 0 auto 48px;
	}

	.actions {
		display: flex;
		gap: 16px;
		justify-content: center;
		flex-wrap: wrap;
	}

	.store-badge {
		display: inline-block;
		border: 1px solid var(--border);
		border-radius: 12px;
		transition: transform 0.2s;
	}

	.store-badge:hover {
		transform: translateY(-2px);
	}

	.store-badge img {
		height: 48px;
		width: auto;
	}

	.badge-dark { display: none; }
	.badge-light { display: block; }

	:global([data-theme="dark"]) .badge-dark { display: block; }
	:global([data-theme="dark"]) .badge-light { display: none; }

	.btn-secondary {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 14px 28px;
		border: 1px solid var(--border);
		color: var(--text-primary);
		border-radius: 100px;
		font-size: 15px;
		font-weight: 500;
		transition: border-color 0.2s, transform 0.2s;
	}

	.btn-secondary:hover {
		border-color: var(--text-muted);
		transform: translateY(-1px);
	}

	@media (max-width: 640px) {
		.hero { padding: 140px 20px 60px; }
		.subtitle { font-size: 16px; }
	}
</style>
