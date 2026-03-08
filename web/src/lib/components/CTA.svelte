<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';

	let email = $state('');
	let submitted = $state(false);
	let submitting = $state(false);
	let error = $state('');
	let turnstileToken = $state('');

	onMount(() => {
		if (browser && window.turnstile) {
			window.turnstile.render('#turnstile-waitlist', {
				sitekey: import.meta.env.VITE_PUBLIC_TURNSTILE_SITE_KEY,
				callback: (token: string) => {
					turnstileToken = token;
				},
				'expired-callback': () => {
					turnstileToken = '';
				},
				theme: 'auto',
				size: 'invisible'
			});
		}
	});

	async function handleJoin(e: Event) {
		e.preventDefault();
		if (submitting) return;

		error = '';
		submitting = true;

		try {
			const res = await fetch('/api/waitlist', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ email, source: 'web', turnstileToken })
			});

			if (res.ok) {
				submitted = true;
			} else {
				const data = await res.json();
				error = data.error || 'Something went wrong. Try again.';
			}
		} catch {
			error = 'Network error. Please try again.';
		} finally {
			submitting = false;
		}
	}
</script>

<section class="cta" id="get-started">
	<div class="inner">
		<div class="card">
			<div class="card-glow"></div>
			<div class="card-content">
				{#if submitted}
					<h2>You're on the list.</h2>
					<p>We'll let you know when CashState is ready for you.</p>
				{:else}
					<h2>Get early access.</h2>
					<p>Join the waitlist and be the first to know when CashState launches.</p>
					<form onsubmit={handleJoin} class="waitlist-form">
						<div class="input-group">
							<input
								type="email"
								bind:value={email}
								placeholder="Enter your email"
								required
								disabled={submitting}
							/>
							<button type="submit" class="btn" disabled={submitting}>
								{submitting ? 'Joining...' : 'Join waitlist'}
							</button>
						</div>
						{#if error}
							<p class="error">{error}</p>
						{/if}
						<div id="turnstile-waitlist"></div>
					</form>
				{/if}
			</div>
		</div>
	</div>
</section>

<style>
	.cta {
		padding: 40px 24px 120px;
	}

	.inner {
		max-width: 900px;
		margin: 0 auto;
	}

	.card {
		position: relative;
		background: var(--text-primary);
		color: var(--bg);
		border-radius: 32px;
		overflow: hidden;
	}

	.card-glow {
		position: absolute;
		top: -50%;
		right: -20%;
		width: 400px;
		height: 400px;
		background: radial-gradient(circle, rgba(45,212,191,0.15) 0%, transparent 70%);
		pointer-events: none;
	}

	.card-content {
		position: relative;
		padding: 80px 48px;
		text-align: center;
	}

	h2 {
		font-size: clamp(32px, 5vw, 48px);
		font-weight: 500;
		letter-spacing: -0.025em;
		line-height: 1.15;
		margin-bottom: 16px;
	}

	p {
		font-size: 18px;
		font-weight: 400;
		opacity: 0.6;
		margin-bottom: 40px;
		max-width: 420px;
		margin-left: auto;
		margin-right: auto;
		line-height: 1.6;
	}

	.waitlist-form {
		max-width: 480px;
		margin: 0 auto;
	}

	.input-group {
		display: flex;
		gap: 8px;
		background: var(--bg);
		border-radius: 100px;
		padding: 6px;
	}

	input {
		flex: 1;
		padding: 12px 20px;
		background: transparent;
		border: none;
		color: var(--text-primary);
		font-size: 15px;
		font-family: var(--font-sans);
		outline: none;
		min-width: 0;
	}

	input::placeholder {
		color: var(--text-muted);
	}

	.btn {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 12px 24px;
		background: var(--text-primary);
		color: var(--bg);
		border-radius: 100px;
		font-size: 14px;
		font-weight: 600;
		transition: opacity 0.2s, transform 0.2s;
		white-space: nowrap;
		cursor: pointer;
		border: none;
		font-family: var(--font-sans);
	}

	.btn:hover:not(:disabled) {
		opacity: 0.85;
		transform: translateY(-1px);
	}

	.btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.error {
		color: #f87171;
		font-size: 14px;
		margin-top: 12px;
		margin-bottom: 0;
		opacity: 1;
	}

	#turnstile-waitlist {
		display: flex;
		justify-content: center;
		margin-top: 8px;
	}

	@media (max-width: 640px) {
		.cta { padding: 40px 20px 80px; }
		.card-content { padding: 56px 28px; }
		.card { border-radius: 24px; }
		.input-group {
			flex-direction: column;
			border-radius: 16px;
			padding: 8px;
		}
		.btn {
			border-radius: 12px;
			justify-content: center;
			padding: 14px 24px;
		}
	}
</style>
