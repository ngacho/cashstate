<script lang="ts">
	import favicon from '$lib/assets/favicon.svg';
	import '../app.css';
	import { browser } from '$app/environment';
	import posthog from 'posthog-js';
	import { onMount } from 'svelte';

	let { children } = $props();

	onMount(() => {
		if (browser && import.meta.env.VITE_PUBLIC_POSTHOG_KEY) {
			posthog.init(import.meta.env.VITE_PUBLIC_POSTHOG_KEY, {
				api_host: import.meta.env.VITE_PUBLIC_POSTHOG_HOST || 'https://us.i.posthog.com',
				capture_pageview: true,
				capture_pageleave: true,
			});
		}
	});
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
	<title>CashState - Know the State of Your Cash</title>
	<meta name="description" content="CashState helps you visualize your income, expenses, and savings in real time - powered by AI insights." />
</svelte:head>

{@render children()}
