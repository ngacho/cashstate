<script lang="ts">
	let scrolled = $state(false);

	function handleScroll() {
		scrolled = window.scrollY > 20;
	}
</script>

<svelte:window onscroll={handleScroll} />

<nav class:scrolled>
	<div class="nav-inner">
		<a href="/" class="logo">
			<span class="logo-icon">$</span>
			<span class="logo-text">CashState</span>
		</a>

		<div class="nav-links">
			<a href="#features">Features</a>
			<a href="#how-it-works">How it works</a>
			<a href="#faq">FAQ</a>
		</div>

		<a href="#get-started" class="cta-btn">
			Get Started
			<svg width="16" height="16" viewBox="0 0 16 16" fill="none">
				<path d="M3 8h10M9 4l4 4-4 4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
			</svg>
		</a>
	</div>
</nav>

<style>
	nav {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		z-index: 100;
		padding: 1rem 2rem;
		transition: all 0.3s ease;
	}

	nav.scrolled {
		background: rgba(255, 255, 255, 0.95);
		backdrop-filter: blur(12px);
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
	}

	.nav-inner {
		max-width: 1200px;
		margin: 0 auto;
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.logo {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-weight: 800;
		font-size: 1.4rem;
		color: var(--color-dark);
	}

	.logo-icon {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 36px;
		height: 36px;
		background: var(--color-primary);
		color: white;
		border-radius: 10px;
		font-size: 1.2rem;
		font-weight: 900;
	}

	.nav-links {
		display: flex;
		gap: 2.5rem;
	}

	.nav-links a {
		font-size: 0.95rem;
		font-weight: 500;
		color: var(--color-text);
		transition: color 0.2s;
	}

	.nav-links a:hover {
		color: var(--color-dark);
	}

	.cta-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.6rem 1.4rem;
		border: 1.5px solid var(--color-border);
		border-radius: 100px;
		font-size: 0.9rem;
		font-weight: 600;
		color: var(--color-dark);
		transition: all 0.2s;
	}

	.cta-btn:hover {
		border-color: var(--color-primary);
		color: var(--color-primary);
	}

	@media (max-width: 768px) {
		.nav-links {
			display: none;
		}
	}
</style>
