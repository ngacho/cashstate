<script lang="ts">
	import favicon from '$lib/assets/favicon.svg';
	import '../app.css';
	import { browser } from '$app/environment';
	import posthog from 'posthog-js';
	import { onMount } from 'svelte';

	let { children } = $props();
	let glow: HTMLDivElement;

	onMount(() => {
		if (browser && import.meta.env.VITE_PUBLIC_POSTHOG_KEY) {
			posthog.init(import.meta.env.VITE_PUBLIC_POSTHOG_KEY, {
				api_host: import.meta.env.VITE_PUBLIC_POSTHOG_HOST || 'https://us.i.posthog.com',
				capture_pageview: true,
				capture_pageleave: true,
			});
		}

		function onMouseMove(e: MouseEvent) {
			if (glow) {
				glow.style.left = e.clientX + 'px';
				glow.style.top = e.clientY + 'px';
			}
		}

		window.addEventListener('mousemove', onMouseMove);
		return () => window.removeEventListener('mousemove', onMouseMove);
	});
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
	<title>CashState - Know the State of Your Cash</title>
	<meta name="description" content="CashState helps you visualize your income, expenses, and savings in real time - powered by AI insights." />
</svelte:head>

<div class="cursor-glow" bind:this={glow}></div>
{@render children()}

<style>
	.cursor-glow {
		position: fixed;
		width: 300px;
		height: 300px;
		border-radius: 50%;
		background: radial-gradient(circle, rgba(13,148,136,0.15) 0%, transparent 70%);
		pointer-events: none;
		z-index: 0;
		transform: translate(-50%, -50%);
		transition: left 0.15s ease-out, top 0.15s ease-out;
		will-change: left, top;
	}

	:global([data-theme="dark"]) .cursor-glow {
		background: radial-gradient(circle, rgba(45,212,191,0.12) 0%, transparent 70%);
	}
</style>
