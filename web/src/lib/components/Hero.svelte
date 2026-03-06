<script lang="ts">
	import RotatingText from './RotatingText.svelte';
</script>

<section class="hero" id="hero">
	<div class="inner">
		<h1>
			Know the state of<br />your <RotatingText />.
		</h1>
		<p class="subtitle">
			The effortless way to track spending, set budgets, and reach your financial goals.
			Beautiful, powerful, and completely free.
		</p>
	</div>
</section>

<style>
	.hero {
		padding: 160px 24px 40px;
		text-align: center;
	}

	.inner {
		max-width: 900px;
		margin: 0 auto;
	}

	h1 {
		font-size: clamp(48px, 8vw, 88px);
		font-weight: 700;
		color: var(--text-primary);
		letter-spacing: -0.03em;
		line-height: 1.05;
		margin-bottom: 28px;
	}

	.subtitle {
		font-size: clamp(17px, 2vw, 22px);
		color: var(--text-secondary);
		line-height: 1.6;
		max-width: 640px;
		margin: 0 auto 48px;
	}

	@media (max-width: 640px) {
		.hero { padding: 120px 16px 40px; }
	}
</style>
