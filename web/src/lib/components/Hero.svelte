<script lang="ts">
	import RotatingText from './RotatingText.svelte';
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
			<a href="/app-store" class="btn-primary">
				<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
					<path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
				</svg>
				Download for free
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

	.btn-primary {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 14px 32px;
		background: var(--accent);
		color: #fff;
		border-radius: 100px;
		font-size: 15px;
		font-weight: 600;
		transition: background 0.2s, transform 0.2s;
	}

	.btn-primary:hover {
		background: var(--accent-hover);
		transform: translateY(-1px);
	}

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
