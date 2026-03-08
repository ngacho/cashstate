<script lang="ts">
	import { onMount } from 'svelte';
	let dark = $state(true);
	let activeHash = $state('#hero');
	let menuOpen = $state(false);

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
		menuOpen = false;
	}

	function toggleMenu() {
		menuOpen = !menuOpen;
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
		<a href="#hero" class="logo" onclick={() => handleClick('#hero')}>
			<img src="/logo.png" alt="CashState" class="logo-img" />
		</a>

		<div class="desktop-links">
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

		<div class="divider"></div>

		<button class="theme-btn" onclick={toggleTheme} aria-label="Toggle theme">
			{#if dark}
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>
			{:else}
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
			{/if}
		</button>

		<a href="#get-started" class="waitlist-btn desktop-only" onclick={() => handleClick('#get-started')}>
			Join waitlist
		</a>

		<button class="hamburger" onclick={toggleMenu} aria-label="Toggle menu" class:open={menuOpen}>
			<span></span>
			<span></span>
			<span></span>
		</button>
	</div>

	{#if menuOpen}
		<div class="mobile-menu">
			{#each links as link}
				<a
					href={link.href}
					class="mobile-link"
					class:active={activeHash === link.href}
					onclick={() => handleClick(link.href)}
				>
					{link.label}
				</a>
			{/each}
			<div class="mobile-divider"></div>
			<a href="#get-started" class="waitlist-btn" onclick={() => handleClick('#get-started')}>
				Join waitlist
			</a>
		</div>
	{/if}
</nav>

<style>
	nav {
		position: fixed;
		top: 20px;
		left: 0;
		right: 0;
		z-index: 100;
		display: flex;
		flex-direction: column;
		align-items: center;
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

	.logo {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 4px 12px;
		text-decoration: none;
		flex-shrink: 0;
	}

	.logo-img {
		width: 28px;
		height: 28px;
		object-fit: contain;
	}

	.desktop-links {
		display: flex;
		align-items: center;
		gap: 4px;
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

	.waitlist-btn {
		display: inline-flex;
		align-items: center;
		flex-shrink: 0;
		padding: 8px 20px;
		background: var(--text-primary);
		color: var(--bg);
		border-radius: 100px;
		font-size: 13px;
		font-weight: 600;
		transition: opacity 0.2s, transform 0.2s;
		white-space: nowrap;
	}

	.waitlist-btn:hover {
		opacity: 0.85;
		transform: translateY(-1px);
	}

	/* Hamburger button - hidden on desktop */
	.hamburger {
		display: none;
		flex-direction: column;
		justify-content: center;
		align-items: center;
		gap: 4px;
		width: 36px;
		height: 36px;
		background: none;
		border: none;
		cursor: pointer;
		padding: 6px;
		flex-shrink: 0;
	}

	.hamburger span {
		display: block;
		width: 18px;
		height: 2px;
		background: var(--text-primary);
		border-radius: 2px;
		transition: all 0.3s ease;
		transform-origin: center;
	}

	.hamburger.open span:nth-child(1) {
		transform: rotate(45deg) translate(3px, 3px);
	}

	.hamburger.open span:nth-child(2) {
		opacity: 0;
	}

	.hamburger.open span:nth-child(3) {
		transform: rotate(-45deg) translate(3px, -3px);
	}

	/* Mobile dropdown menu */
	.mobile-menu {
		display: none;
	}

	@media (max-width: 640px) {
		nav {
			padding: 0 12px;
		}

		.pill {
			width: 100%;
			gap: 0;
			padding: 4px 4px 4px 6px;
		}

		.logo {
			padding: 4px 8px;
			margin-right: auto;
		}

		.logo-img {
			width: 28px;
			height: 28px;
		}

		.desktop-links {
			display: none;
		}

		.desktop-only {
			display: none;
		}

		.divider {
			display: none;
		}

		.hamburger {
			display: flex;
		}

		.theme-btn {
			width: 32px;
			height: 32px;
		}

		.mobile-menu {
			display: flex;
			flex-direction: column;
			align-items: stretch;
			gap: 4px;
			margin-top: 8px;
			padding: 12px;
			border-radius: 20px;
			background: var(--nav-bg);
			backdrop-filter: blur(20px);
			-webkit-backdrop-filter: blur(20px);
			border: 1px solid var(--nav-border);
			box-shadow: 0 4px 24px rgba(0,0,0,0.08);
			pointer-events: auto;
			width: 100%;
		}

		.mobile-link {
			font-size: 15px;
			font-weight: 500;
			color: var(--text-muted);
			padding: 12px 16px;
			border-radius: 12px;
			transition: all 0.2s ease;
		}

		.mobile-link.active {
			background: var(--card-bg);
			color: var(--text-primary);
			font-weight: 600;
		}

		.mobile-divider {
			height: 1px;
			background: var(--border);
			margin: 4px 0;
		}

		.mobile-menu .waitlist-btn {
			align-self: center;
			margin-top: 4px;
			text-align: center;
		}
	}
</style>
