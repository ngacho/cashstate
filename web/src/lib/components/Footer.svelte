<footer>
	<div class="inner">
		<div class="top">
			<div class="brand">
				<span class="logo">Cash<span class="accent">State</span></span>
				<p class="tagline">Know your state.</p>
			</div>

			<div class="col">
				<h4>Product</h4>
				<a href="#features">Features</a>
				<a href="#how-it-works">How it works</a>
				<a href="/app-store">Download</a>
			</div>

			<div class="col">
				<h4>Support</h4>
				<a href="#faq">FAQ</a>
			</div>
		</div>

		<div class="bottom">
			<p>&copy; {new Date().getFullYear()} CashState. All rights reserved.</p>
		</div>
	</div>
</footer>

<style>
	footer {
		padding: 64px 24px 32px;
		border-top: 1px solid var(--border);
	}

	.inner {
		max-width: var(--container);
		margin: 0 auto;
	}

	.top {
		display: grid;
		grid-template-columns: 2fr 1fr 1fr;
		gap: 48px;
		margin-bottom: 48px;
	}

	.logo {
		font-size: 18px;
		font-weight: 700;
		color: var(--text-primary);
		letter-spacing: -0.02em;
	}

	.accent {
		color: var(--accent);
	}

	.tagline {
		font-size: 14px;
		color: var(--text-muted);
		margin-top: 8px;
	}

	.col {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	h4 {
		font-size: 13px;
		font-weight: 600;
		color: var(--text-primary);
		margin-bottom: 4px;
	}

	.col a {
		font-size: 14px;
		color: var(--text-secondary);
		transition: color 0.2s;
	}

	.col a:hover {
		color: var(--text-primary);
	}

	.bottom {
		padding-top: 24px;
		border-top: 1px solid var(--border);
	}

	.bottom p {
		font-size: 13px;
		color: var(--text-muted);
	}

	@media (max-width: 640px) {
		footer { padding: 40px 16px 24px; }
		.top {
			grid-template-columns: 1fr;
			gap: 32px;
		}
	}
</style>
