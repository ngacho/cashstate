<script lang="ts">
	import { onMount } from 'svelte';
	import appStoreLight from '$lib/assets/Download-AppStore.png';
	import appStoreDark from '$lib/assets/Download-AppStoreDark.png';

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

		<div class="divider"></div>

		<button class="theme-btn" onclick={toggleTheme} aria-label="Toggle theme">
			{#if dark}
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>
			{:else}
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
			{/if}
		</button>

		<a href="/app-store" class="download-btn" aria-label="Download on the App Store">
			<img class="badge-light" src={appStoreLight} alt="Download on the App Store" />
			<img class="badge-dark" src={appStoreDark} alt="Download on the App Store" />
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
		color: var(--text-muted);
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
		box-shadow: 0 2px 8px rgba(0,0,0,0.06);
	}

	.divider {
		width: 1px;
		height: 20px;
		background: var(--border);
		margin: 0 4px;
		flex-shrink: 0;
	}

	.theme-btn {
		width: 36px;
		height: 36px;
		display: flex;
		align-items: center;
		justify-content: center;
		color: var(--text-muted);
		border-radius: 50%;
		transition: color 0.2s;
		flex-shrink: 0;
	}

	.theme-btn:hover {
		color: var(--text-primary);
	}

	.download-btn {
		display: inline-flex;
		align-items: center;
		flex-shrink: 0;
		border: 1px solid var(--border);
		border-radius: 8px;
		transition: transform 0.2s;
	}

	.download-btn:hover {
		transform: translateY(-1px);
	}

	.download-btn img {
		height: 32px;
		width: auto;
	}

	.badge-dark { display: none; }
	.badge-light { display: block; }

	:global([data-theme="dark"]) .badge-dark { display: block; }
	:global([data-theme="dark"]) .badge-light { display: none; }

	@media (max-width: 640px) {
		.pill {
			gap: 2px;
			padding: 4px;
		}

		.nav-link {
			font-size: 13px;
			padding: 8px 12px;
		}

		.divider { display: none; }

		.theme-btn {
			width: 32px;
			height: 32px;
		}

		.download-btn img {
			height: 28px;
		}
	}
</style>
