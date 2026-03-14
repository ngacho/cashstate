<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';

	let email = $state('');
	let submitted = $state(false);
	let submitting = $state(false);
	let error = $state('');
	let turnstileToken = $state('');

	function renderTurnstile() {
		if (!window.turnstile) return;
		const el = document.getElementById('turnstile-waitlist');
		if (!el) return;
		window.turnstile.render('#turnstile-waitlist', {
			sitekey: import.meta.env.VITE_PUBLIC_TURNSTILE_SITE_KEY,
			callback: (token: string) => {
				turnstileToken = token;
			},
			'expired-callback': () => {
				turnstileToken = '';
			},
			theme: 'auto'
		});
	}

	onMount(() => {
		if (!browser) return;
		if (window.turnstile) {
			renderTurnstile();
		} else {
			// Turnstile script hasn't loaded yet — poll until ready
			const interval = setInterval(() => {
				if (window.turnstile) {
					clearInterval(interval);
					renderTurnstile();
				}
			}, 200);
			return () => clearInterval(interval);
		}
	});

	async function handleJoin(e: SubmitEvent) {
		e.preventDefault();
		if (submitting) return;

		error = '';

		if (!email.trim()) {
			error = 'Please enter your email.';
			return;
		}

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
				let msg = 'Something went wrong. Try again.';
				try {
					const data = await res.json();
					msg = data.error || msg;
				} catch {
					// response wasn't JSON
				}
				error = msg;
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
						{#if error}
							<p class="error">{error}</p>
						{/if}
						<div class="input-group">
							<input
								type="email"
								bind:value={email}
								placeholder="Enter your email"
								required
								disabled={submitting}
							/>
							<button type="submit" class="btn" disabled={submitting}>
								{#if submitting}
									<span class="spinner"></span>
									Joining...
								{:else}
									Join waitlist
								{/if}
							</button>
						</div>
						<div id="turnstile-waitlist"></div>
					</form>
					<a href="/guides/setup-simplefin" class="setup-link">
						Need help setting up SimpleFin?
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/><polyline points="12 5 19 12 12 19"/></svg>
					</a>
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
		background: var(--card-bg);
		color: var(--text-primary);
		border: 1px solid var(--card-border);
		border-radius: 32px;
		overflow: hidden;
	}

	.card-glow {
		position: absolute;
		top: -50%;
		right: -20%;
		width: 400px;
		height: 400px;
		background: radial-gradient(circle, rgba(45,212,191,0.1) 0%, transparent 70%);
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
		color: var(--text-secondary);
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
		border: 1px solid var(--border);
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
		margin-top: 0;
		margin-bottom: 12px;
		opacity: 1;
	}

	.spinner {
		width: 14px;
		height: 14px;
		border: 2px solid transparent;
		border-top-color: currentColor;
		border-radius: 50%;
		animation: spin 0.6s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	#turnstile-waitlist {
		display: flex;
		justify-content: center;
		margin-top: 8px;
	}

	.setup-link {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		margin-top: 24px;
		font-size: 14px;
		color: var(--accent);
		font-weight: 500;
		transition: opacity 0.2s;
	}

	.setup-link:hover {
		opacity: 0.75;
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
