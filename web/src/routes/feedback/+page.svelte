<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';

	let email = $state('');
	let type = $state('general');
	let message = $state('');
	let submitted = $state(false);
	let submitting = $state(false);
	let error = $state('');
	let turnstileToken = $state('');

	onMount(() => {
		if (browser && window.turnstile) {
			window.turnstile.render('#turnstile-feedback', {
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

	async function handleSubmit(e: Event) {
		e.preventDefault();
		if (submitting) return;

		error = '';
		submitting = true;

		try {
			const source = new URLSearchParams(window.location.search).get('source') ?? 'web';
			const res = await fetch('/api/feedback', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ email, type, message, source, turnstileToken })
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

<svelte:head>
	<title>Feedback - CashState</title>
</svelte:head>

<main class="feedback-page">
	<div class="container">
		{#if submitted}
			<div class="success">
				<div class="check-icon">
					<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="var(--accent)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
						<polyline points="20 6 9 17 4 12"></polyline>
					</svg>
				</div>
				<h1>Thanks for your feedback!</h1>
				<p>We read every submission and use it to make CashState better.</p>
				<a href="/" class="btn-back">Back to home</a>
			</div>
		{:else}
			<h1>Send us feedback</h1>
			<p class="subtitle">Bug, feature idea, or just want to say hi? We'd love to hear from you.</p>

			<form onsubmit={handleSubmit} class="feedback-form">
				<div class="field">
					<label for="feedback-type">Type</label>
					<select id="feedback-type" bind:value={type}>
						<option value="general">General</option>
						<option value="bug">Bug report</option>
						<option value="feature">Feature request</option>
					</select>
				</div>

				<div class="field">
					<label for="feedback-message">Message</label>
					<textarea
						id="feedback-message"
						bind:value={message}
						placeholder="What's on your mind?"
						required
						rows="5"
						disabled={submitting}
					></textarea>
				</div>

				<div class="field">
					<label for="feedback-email">Email <span class="optional">(optional)</span></label>
					<input
						id="feedback-email"
						type="email"
						bind:value={email}
						placeholder="your@email.com"
						disabled={submitting}
					/>
				</div>

				{#if error}
					<p class="error">{error}</p>
				{/if}

				<div id="turnstile-feedback"></div>

				<button type="submit" class="btn-submit" disabled={submitting}>
					{submitting ? 'Sending...' : 'Send feedback'}
				</button>
			</form>
		{/if}
	</div>
</main>

<style>
	.feedback-page {
		min-height: 100vh;
		padding: 120px 24px 80px;
		display: flex;
		justify-content: center;
	}

	.container {
		max-width: 520px;
		width: 100%;
	}

	h1 {
		font-size: clamp(28px, 5vw, 36px);
		font-weight: 500;
		color: var(--text-primary);
		letter-spacing: -0.025em;
		margin-bottom: 12px;
	}

	.subtitle {
		color: var(--text-secondary);
		font-size: 16px;
		margin-bottom: 40px;
		line-height: 1.6;
	}

	.feedback-form {
		display: flex;
		flex-direction: column;
		gap: 24px;
	}

	.field {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	label {
		font-size: 14px;
		font-weight: 500;
		color: var(--text-primary);
	}

	.optional {
		font-weight: 400;
		color: var(--text-muted);
	}

	input, textarea, select {
		padding: 12px 16px;
		background: var(--card-bg);
		border: 1px solid var(--card-border);
		border-radius: 12px;
		color: var(--text-primary);
		font-size: 15px;
		font-family: var(--font-sans);
		outline: none;
		transition: border-color 0.2s;
	}

	input:focus, textarea:focus, select:focus {
		border-color: var(--accent);
	}

	input::placeholder, textarea::placeholder {
		color: var(--text-muted);
	}

	textarea {
		resize: vertical;
		min-height: 120px;
	}

	select {
		cursor: pointer;
		appearance: none;
		background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 20 20'%3e%3cpath stroke='%2394A3B8' stroke-linecap='round' stroke-linejoin='round' stroke-width='1.5' d='M6 8l4 4 4-4'/%3e%3c/svg%3e");
		background-position: right 12px center;
		background-repeat: no-repeat;
		background-size: 20px;
		padding-right: 40px;
	}

	.btn-submit {
		padding: 14px 28px;
		background: var(--accent);
		color: #fff;
		border: none;
		border-radius: 12px;
		font-size: 15px;
		font-weight: 600;
		font-family: var(--font-sans);
		cursor: pointer;
		transition: opacity 0.2s, transform 0.2s;
	}

	.btn-submit:hover:not(:disabled) {
		opacity: 0.9;
		transform: translateY(-1px);
	}

	.btn-submit:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.error {
		color: #f87171;
		font-size: 14px;
	}

	#turnstile-feedback {
		display: flex;
		justify-content: center;
	}

	.success {
		text-align: center;
		padding-top: 60px;
	}

	.check-icon {
		margin-bottom: 24px;
	}

	.success p {
		color: var(--text-secondary);
		font-size: 16px;
		margin-bottom: 32px;
		line-height: 1.6;
	}

	.btn-back {
		display: inline-flex;
		align-items: center;
		padding: 12px 24px;
		border: 1px solid var(--border);
		border-radius: 100px;
		color: var(--text-primary);
		font-size: 14px;
		font-weight: 500;
		transition: border-color 0.2s;
	}

	.btn-back:hover {
		border-color: var(--text-muted);
	}

	@media (max-width: 640px) {
		.feedback-page { padding: 100px 20px 60px; }
	}
</style>
