<script lang="ts">
	import { carouselItems, carouselIndex } from '$lib/theme.svelte';

	let isAnimating = $state(false);
	let displayIndex = $state(carouselIndex.value);

	$effect(() => {
		if (carouselIndex.value !== displayIndex) {
			isAnimating = true;
			setTimeout(() => {
				displayIndex = carouselIndex.value;
				isAnimating = false;
			}, 500);
		}
	});
</script>

<span class="wrap"><span class="word" class:out={isAnimating}>{carouselItems[displayIndex]}</span></span>

<style>
	.wrap {
		display: inline;
	}

	.word {
		color: var(--accent);
		font-family: var(--font-sans);
		font-weight: 700;
		transition: opacity 0.5s cubic-bezier(0.4, 0, 0.2, 1);
	}

	.word.out {
		opacity: 0;
	}
</style>
