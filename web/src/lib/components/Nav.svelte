<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';

	let scrolled = $state(false);
	let dark = $state(true);

	function handleScroll() {
		scrolled = window.scrollY > 20;
	}

	function toggleTheme() {
		dark = !dark;
		document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
		localStorage.setItem('theme', dark ? 'dark' : 'light');
	}

	onMount(() => {
		const saved = localStorage.getItem('theme');
		if (saved) {
			dark = saved === 'dark';
		} else {
			dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
		}
		document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
	});
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

		<div class="nav-actions">
			<button class="theme-toggle" onclick={toggleTheme} aria-label="Toggle theme">
				{#if dark}
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
						<circle cx="12" cy="12" r="5"></circle>
						<line x1="12" y1="1" x2="12" y2="3"></line>
						<line x1="12" y1="21" x2="12" y2="23"></line>
						<line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line>
						<line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line>
						<line x1="1" y1="12" x2="3" y2="12"></line>
						<line x1="21" y1="12" x2="23" y2="12"></line>
						<line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line>
						<line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line>
					</svg>
				{:else}
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
						<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
					</svg>
				{/if}
			</button>

			<a href="#get-started" class="cta-btn">
				<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
					<path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
				</svg>
				App Store
			</a>
		</div>
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
		background: var(--color-nav-bg);
		backdrop-filter: blur(12px);
		box-shadow: 0 1px 3px var(--color-shadow);
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
		color: var(--color-white);
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

	.nav-actions {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.theme-toggle {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 36px;
		height: 36px;
		border-radius: 10px;
		background: var(--color-card);
		border: 1px solid var(--color-border);
		color: var(--color-text);
		transition: all 0.2s;
	}

	.theme-toggle:hover {
		color: var(--color-primary);
		border-color: var(--color-primary);
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
