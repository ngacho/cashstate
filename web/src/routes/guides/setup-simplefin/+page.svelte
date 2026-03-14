<script lang="ts">
</script>

<svelte:head>
	<title>How to Set Up SimpleFin - CashState</title>
	<meta name="description" content="Step-by-step guide to getting your SimpleFin token and connecting it to CashState." />
</svelte:head>

<main class="guide-page">
	<div class="container">
		<a href="/" class="back-link">
			<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5"/><polyline points="12 19 5 12 12 5"/></svg>
			Back to home
		</a>

		<div class="header">
			<span class="label">Guide</span>
			<h1>How to Set Up SimpleFin</h1>
			<p class="subtitle">Get your SimpleFin token and connect your bank accounts to CashState in a few minutes.</p>
		</div>

		<div class="steps">
			<div class="step">
				<div class="num-wrap">
					<span class="num">1</span>
					<div class="connector"></div>
				</div>
				<div class="content">
					<h3>Go to SimpleFin and click Get Started</h3>
					<p>Head to <a href="https://simplefin.org" target="_blank" rel="noopener noreferrer" class="link">simplefin.org</a> and click the <strong>Get Started</strong> button. This will take you to the SimpleFin Bridge where you'll create your account.</p>
				</div>
			</div>

			<div class="step">
				<div class="num-wrap">
					<span class="num">2</span>
					<div class="connector"></div>
				</div>
				<div class="content">
					<h3>Create an account</h3>
					<p>Enter your email and create a password. SimpleFin will send you a verification email — click the link to confirm your account.</p>
				</div>
			</div>

			<div class="step">
				<div class="num-wrap">
					<span class="num">3</span>
					<div class="connector"></div>
				</div>
				<div class="content">
					<h3>Click Billing and pay</h3>
					<p>Navigate to the <strong>Billing</strong> section and complete payment. SimpleFin costs just <strong>$1.50/month</strong> — less than a cup of coffee. This gives you read-only access to up to 25 bank accounts.</p>
				</div>
			</div>

			<div class="step">
				<div class="num-wrap">
					<span class="num">4</span>
					<div class="connector"></div>
				</div>
				<div class="content">
					<h3>Go to Apps and create a new connection</h3>
					<p>After paying, go to the <strong>Apps</strong> tab and click <strong>New Connection</strong>. This generates a unique setup token that CashState uses to securely pull your financial data.</p>
				</div>
			</div>

			<div class="step">
				<div class="num-wrap">
					<span class="num">5</span>
					<div class="connector"></div>
				</div>
				<div class="content">
					<h3>Copy your token</h3>
					<p>SimpleFin will display a setup token — a long string of characters. Copy it to your clipboard. You'll only see this once, so don't close the page yet.</p>
				</div>
			</div>

			<div class="step">
				<div class="num-wrap">
					<span class="num">6</span>
					<div class="connector"></div>
				</div>
				<div class="content">
					<h3>Paste it in CashState</h3>
					<p>Open CashState on your iPhone. During onboarding, tap <strong>"I already have a key"</strong> and paste your token. Or if you're already signed in, go to <strong>Settings</strong> and tap <strong>"Connect SimpleFin"</strong>.</p>
				</div>
			</div>

			<div class="step">
				<div class="num-wrap">
					<span class="num">7</span>
				</div>
				<div class="content">
					<h3>Add your bank accounts</h3>
					<p>Now you need to link your actual banks to SimpleFin so it can read your transactions. Check out our <a href="/guides/add-accounts" class="link">guide on adding bank accounts</a> for the full walkthrough.</p>
				</div>
			</div>
		</div>

		<div class="callout">
			<div class="callout-icon">
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>
			</div>
			<div>
				<strong>Good to know:</strong> SimpleFin only provides <em>read-only</em> access. Nobody — not CashState, not SimpleFin — can move your money or make changes to your accounts.
			</div>
		</div>

		<div class="next-guide">
			<a href="/guides/add-accounts" class="next-link">
				<span class="next-label">Next guide</span>
				<span class="next-title">How to Add Bank Accounts on SimpleFin</span>
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/><polyline points="12 5 19 12 12 19"/></svg>
			</a>
		</div>
	</div>
</main>

<style>
	.guide-page {
		min-height: 100vh;
		padding: 120px 24px 80px;
		display: flex;
		justify-content: center;
	}

	.container {
		max-width: 640px;
		width: 100%;
	}

	.back-link {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		font-size: 14px;
		color: var(--text-muted);
		transition: color 0.2s;
		margin-bottom: 40px;
	}

	.back-link:hover {
		color: var(--text-primary);
	}

	.header {
		margin-bottom: 48px;
	}

	.label {
		display: inline-block;
		padding: 6px 16px;
		background: var(--accent-light);
		color: var(--accent);
		border-radius: 100px;
		font-size: 12px;
		font-weight: 600;
		letter-spacing: 0.06em;
		text-transform: uppercase;
		margin-bottom: 20px;
	}

	h1 {
		font-size: clamp(28px, 5vw, 40px);
		font-weight: 500;
		color: var(--text-primary);
		letter-spacing: -0.025em;
		line-height: 1.15;
		margin-bottom: 16px;
	}

	.subtitle {
		font-size: 16px;
		color: var(--text-secondary);
		line-height: 1.7;
	}

	.steps {
		display: flex;
		flex-direction: column;
		margin-bottom: 48px;
	}

	.step {
		display: flex;
		gap: 24px;
	}

	.num-wrap {
		display: flex;
		flex-direction: column;
		align-items: center;
		flex-shrink: 0;
	}

	.num {
		width: 48px;
		height: 48px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: var(--accent);
		color: #fff;
		border-radius: 50%;
		font-family: var(--font-sans);
		font-size: 20px;
		font-weight: 600;
		flex-shrink: 0;
	}

	.connector {
		width: 2px;
		flex: 1;
		background: var(--border);
		margin: 8px 0;
	}

	.content {
		padding: 8px 0 40px;
	}

	.step:last-child .content {
		padding-bottom: 0;
	}

	h3 {
		font-size: 18px;
		font-weight: 600;
		letter-spacing: -0.01em;
		color: var(--text-primary);
		margin-bottom: 8px;
	}

	.step p {
		font-size: 15px;
		color: var(--text-secondary);
		line-height: 1.7;
	}

	.link {
		color: var(--accent);
		text-decoration: underline;
		text-underline-offset: 2px;
	}

	.link:hover {
		opacity: 0.8;
	}

	.callout {
		display: flex;
		gap: 12px;
		padding: 20px;
		background: var(--accent-light);
		border: 1px solid var(--accent);
		border-radius: 12px;
		font-size: 14px;
		color: var(--text-secondary);
		line-height: 1.6;
		margin-bottom: 40px;
	}

	.callout-icon {
		flex-shrink: 0;
		color: var(--accent);
		margin-top: 1px;
	}

	.callout strong {
		color: var(--text-primary);
	}

	.next-guide {
		padding-top: 40px;
		border-top: 1px solid var(--border);
	}

	.next-link {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 20px;
		border: 1px solid var(--border);
		border-radius: 12px;
		transition: border-color 0.2s, background 0.2s;
	}

	.next-link:hover {
		border-color: var(--accent);
		background: var(--accent-light);
	}

	.next-label {
		font-size: 12px;
		font-weight: 600;
		color: var(--text-muted);
		text-transform: uppercase;
		letter-spacing: 0.06em;
	}

	.next-title {
		flex: 1;
		font-size: 15px;
		font-weight: 600;
		color: var(--text-primary);
	}

	.next-link svg {
		color: var(--accent);
		flex-shrink: 0;
	}

	@media (max-width: 640px) {
		.guide-page { padding: 100px 20px 60px; }
		.num { width: 40px; height: 40px; font-size: 18px; }
		.step { gap: 16px; }
		.next-link { flex-wrap: wrap; }
	}
</style>
