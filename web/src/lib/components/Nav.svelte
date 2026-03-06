<script lang="ts">
	import { onMount } from 'svelte';

	let dark = $state(true);
	let activeHash = $state('#hero');

	const links = [
		{ href: '#hero', label: 'Home' },
		{ href: '#features', label: 'Features' },
		{ href: '#how-it-works', label: 'How it works' },
		{ href: '#faq', label: 'FAQ' },
	];

	function toggleTheme() {
		dark = !dark;
		document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
		localStorage.setItem('theme', dark ? 'dark' : 'light');
	}

	function handleClick(href: string) {
		activeHash = href;
	}

	onMount(() => {
		const saved = localStorage.getItem('theme');
		if (saved) {
			dark = saved === 'dark';
		} else {
			dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
		}
		document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');

		// Track active section on scroll
		const observer = new IntersectionObserver(
			(entries) => {
				for (const entry of entries) {
					if (entry.isIntersecting) {
						activeHash = '#' + entry.target.id;
					}
				}
			},
			{ threshold: 0.3 }
		);

		for (const link of links) {
			const el = document.querySelector(link.href);
			if (el) observer.observe(el);
		}

		return () => observer.disconnect();
	});
</script>

<nav>
	<div class="pill">
		{#each links as link}
			<a
				href={link.href}
				class="nav-link"
				class:active={activeHash === link.href}
				onclick={() => handleClick(link.href)}
			>
				{link.label}
			</a>
		{/each}
	</div>

	<div class="side-actions">
		<button class="theme-btn" onclick={toggleTheme} aria-label="Toggle theme">
			{#if dark}
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>
			{:else}
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
			{/if}
		</button>
		<a href="/app-store" class="download-btn">
			<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
				<path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
			</svg>
			Download
		</a>
	</div>
</nav>

<style>
	nav {
		position: fixed;
		top: 20px;
		left: 0;
		right: 0;
		z-index: 100;
		display: flex;
		justify-content: center;
		align-items: center;
		gap: 16px;
		padding: 0 24px;
		pointer-events: none;
	}

	.pill {
		display: flex;
		align-items: center;
		gap: 4px;
		padding: 6px;
		border-radius: 100px;
		background: var(--nav-bg);
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid var(--nav-border);
		box-shadow: 0 4px 24px rgba(0,0,0,0.08);
		pointer-events: auto;
	}

	.nav-link {
		font-size: 14px;
		font-weight: 500;
		color: var(--text-secondary);
		padding: 10px 24px;
		border-radius: 100px;
		transition: all 0.25s ease;
		white-space: nowrap;
	}

	.nav-link:hover {
		color: var(--text-primary);
	}

	.nav-link.active {
		background: var(--card-bg);
		color: var(--text-primary);
		font-weight: 600;
		box-shadow: 0 1px 4px rgba(0,0,0,0.06);
	}

	.side-actions {
		position: fixed;
		top: 20px;
		right: 24px;
		display: flex;
		align-items: center;
		gap: 12px;
		pointer-events: auto;
	}

	.theme-btn {
		width: 40px;
		height: 40px;
		display: flex;
		align-items: center;
		justify-content: center;
		color: var(--text-secondary);
		border-radius: 50%;
		background: var(--nav-bg);
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid var(--nav-border);
		transition: color 0.2s;
	}

	.theme-btn:hover {
		color: var(--text-primary);
	}

	.download-btn {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		padding: 10px 20px;
		background: var(--text-primary);
		color: var(--bg);
		border-radius: 100px;
		font-size: 13px;
		font-weight: 600;
		transition: opacity 0.2s;
	}

	.download-btn:hover {
		opacity: 0.85;
	}

	@media (max-width: 640px) {
		.pill {
			gap: 2px;
			padding: 4px;
		}

		.nav-link {
			font-size: 13px;
			padding: 8px 14px;
		}

		.side-actions {
			display: none;
		}
	}
</style>
