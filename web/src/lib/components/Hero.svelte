<script lang="ts">
	import RotatingText from './RotatingText.svelte';
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
			Know the State of Your<br/>
			<RotatingText /> with<br/>
			Intelligent <span class="highlight-clarity">Clarity</span>
		</h1>
	</div>
</section>

<style>
	.hero {
		min-height: 60vh;
		padding: 8rem 2rem 2rem;
		text-align: center;
		display: flex;
		align-items: center;
		justify-content: center;
		position: relative;
		overflow: hidden;
		background: var(--color-white);
	}

	.hero-inner {
		max-width: 800px;
		margin: 0 auto;
	}

	.pill {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1.2rem;
		background: var(--color-card);
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
		line-height: 1.2;
		color: var(--color-dark);
		letter-spacing: -0.02em;
	}

	.highlight-clarity {
		color: var(--color-primary);
	}

	@media (max-width: 768px) {
		.hero {
			padding: 6rem 1.5rem 2rem;
		}
	}
</style>
