<script lang="ts">
	import { carouselItems } from '$lib/theme';
	import { onMount, onDestroy } from 'svelte';

	let currentIndex = $state(0);
	let isAnimating = $state(false);
	let interval: ReturnType<typeof setInterval>;

	onMount(() => {
		interval = setInterval(() => {
			isAnimating = true;
			setTimeout(() => {
				currentIndex = (currentIndex + 1) % carouselItems.length;
				isAnimating = false;
			}, 400);
		}, 3000);
	});

	onDestroy(() => {
		if (interval) clearInterval(interval);
	});
</script>

<span class="rotating-wrapper">
	<span class="rotating-text" class:animating={isAnimating}>
		{carouselItems[currentIndex]}
	</span>
</span>

<style>
	.rotating-wrapper {
		display: inline-block;
		position: relative;
		min-width: 200px;
	}

	.rotating-text {
		display: inline-block;
		background: linear-gradient(135deg, var(--color-primary), var(--color-accent));
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
		transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
		opacity: 1;
		transform: translateY(0);
	}

	.rotating-text.animating {
		opacity: 0;
		transform: translateY(20px);
	}
</style>
