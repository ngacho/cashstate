<script lang="ts">
</script>

<svelte:head>
	<title>How to Add Bank Accounts on SimpleFin - CashState</title>
	<meta name="description" content="Step-by-step guide to connecting your bank accounts through SimpleFin Bridge." />
</svelte:head>

<main class="guide-page">
	<div class="container">
		<a href="/" class="back-link">
			<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5"/><polyline points="12 19 5 12 12 5"/></svg>
			Back to home
		</a>

		<div class="header">
			<span class="label">Guide</span>
			<h1>How to Add Bank Accounts on SimpleFin</h1>
			<p class="subtitle">Connect your banks to SimpleFin so CashState can sync your transactions and balances.</p>
		</div>

		<div class="prereq">
			<strong>Before you start:</strong> You need a SimpleFin account with an active subscription. If you haven't set one up yet, follow our <a href="/guides/setup-simplefin" class="link">SimpleFin setup guide</a> first.
		</div>

		<div class="steps">
			<div class="step">
				<div class="num-wrap">
					<span class="num">1</span>
					<div class="connector"></div>
				</div>
				<div class="content">
					<h3>Go to SimpleFin Bridge</h3>
					<p>Visit <a href="https://beta-bridge.simplefin.org" target="_blank" rel="noopener noreferrer" class="link">beta-bridge.simplefin.org</a> and sign in with your SimpleFin account. This is the dashboard where you manage all your bank connections.</p>
				</div>
			</div>

			<div class="step">
				<div class="num-wrap">
					<span class="num">2</span>
					<div class="connector"></div>
				</div>
				<div class="content">
					<h3>Click "Add a bank account"</h3>
					<p>On the Bridge dashboard, click the button to add a new bank account. SimpleFin will show you a search bar to find your bank.</p>
				</div>
			</div>

			<div class="step">
				<div class="num-wrap">
					<span class="num">3</span>
					<div class="connector"></div>
				</div>
				<div class="content">
					<h3>Search for your bank</h3>
					<p>Type your bank's name (e.g. "Chase", "Bank of America", "Ally"). SimpleFin supports thousands of financial institutions across the US. Select yours from the results.</p>
				</div>
			</div>

			<div class="step">
				<div class="num-wrap">
					<span class="num">4</span>
					<div class="connector"></div>
				</div>
				<div class="content">
					<h3>Sign in to your bank</h3>
					<p>You'll be asked to enter your bank's login credentials. These go directly to your bank — SimpleFin acts as a secure intermediary. You may need to complete multi-factor authentication (text code, email code, etc.).</p>
				</div>
			</div>

			<div class="step">
				<div class="num-wrap">
					<span class="num">5</span>
					<div class="connector"></div>
				</div>
				<div class="content">
					<h3>Select which accounts to connect</h3>
					<p>After signing in, you'll see a list of your accounts at that bank (checking, savings, credit cards, etc.). Select the ones you want CashState to track. You can always change this later.</p>
				</div>
			</div>

			<div class="step">
				<div class="num-wrap">
					<span class="num">6</span>
				</div>
				<div class="content">
					<h3>Repeat for other banks</h3>
					<p>Got accounts at multiple banks? Repeat steps 2-5 for each one. SimpleFin supports up to 25 accounts on a single subscription. Once connected, CashState will automatically sync all your transactions and balances.</p>
				</div>
			</div>
		</div>

		<div class="callout">
			<div class="callout-icon">
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
			</div>
			<div>
				<strong>Your credentials are safe.</strong> Your bank login goes directly to your bank through SimpleFin's secure connection. CashState never sees or stores your bank password — we only receive read-only transaction data.
			</div>
		</div>

		<div class="callout info">
			<div class="callout-icon">
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>
			</div>
			<div>
				<strong>Bank not showing up?</strong> Some smaller banks or credit unions may not be supported yet. SimpleFin is constantly adding new institutions. Check back later or <a href="/feedback" class="link">let us know</a> which bank you need.
			</div>
		</div>

		<div class="next-guide">
			<a href="/guides/setup-simplefin" class="next-link">
				<span class="next-label">Previous guide</span>
				<span class="next-title">How to Set Up SimpleFin</span>
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5"/><polyline points="12 19 5 12 12 5"/></svg>
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
		margin-bottom: 32px;
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

	.prereq {
		padding: 16px 20px;
		background: var(--card-bg);
		border: 1px solid var(--card-border);
		border-radius: 12px;
		font-size: 14px;
		color: var(--text-secondary);
		line-height: 1.6;
		margin-bottom: 48px;
	}

	.prereq strong {
		color: var(--text-primary);
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
		margin-bottom: 16px;
	}

	.callout-icon {
		flex-shrink: 0;
		color: var(--accent);
		margin-top: 1px;
	}

	.callout strong {
		color: var(--text-primary);
	}

	.callout.info {
		background: var(--card-bg);
		border-color: var(--card-border);
		margin-bottom: 40px;
	}

	.callout.info .callout-icon {
		color: var(--text-muted);
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
