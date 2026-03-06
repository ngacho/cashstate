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
		display: inline-block;
		overflow: hidden;
		vertical-align: bottom;
		min-width: 60px;
	}

	.word {
		display: inline-block;
		color: var(--accent);
		font-weight: 700;
		transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
	}

	.word.out {
		opacity: 0;
		transform: translateY(100%);
	}
</style>
