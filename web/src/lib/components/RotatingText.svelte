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
			}, 250);
		}
	});
</script>

<span class="wrap"><span class="word" class:out={isAnimating}>{carouselItems[displayIndex]}</span></span>

<style>
	.wrap {
		display: inline;
		min-width: 60px;
	}

	.word {
		color: var(--accent);
		font-family: var(--font-serif);
		font-weight: 400;
		transition: opacity 0.25s cubic-bezier(0.4, 0, 0.2, 1);
	}

	.word.out {
		opacity: 0;
	}
</style>
