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
				<!-- TODO: restore Download link when live -->
				<a href="#get-started">Join waitlist</a>
			</div>

			<div class="col">
				<h4>Guides</h4>
				<a href="/guides/setup-simplefin">Set up SimpleFin</a>
				<a href="/guides/add-accounts">Add bank accounts</a>
			</div>

			<div class="col">
				<h4>Support</h4>
				<a href="#faq">FAQ</a>
				<a href="/feedback">Feedback</a>
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
		max-width: 900px;
		margin: 0 auto;
	}

	.top {
		display: grid;
		grid-template-columns: 2fr 1fr 1fr 1fr;
		gap: 48px;
		margin-bottom: 48px;
	}

	.logo {
		font-family: var(--font-sans);
		font-size: 22px;
		font-weight: 600;
		color: var(--text-primary);
	}

	.accent {
		color: var(--accent);
	}

	.tagline {
		font-size: 14px;
		color: var(--text-muted);
		margin-top: 10px;
		line-height: 1.6;
	}

	.col {
		display: flex;
		flex-direction: column;
		gap: 14px;
	}

	h4 {
		font-size: 12px;
		font-weight: 600;
		color: var(--text-muted);
		letter-spacing: 0.06em;
		text-transform: uppercase;
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
		footer { padding: 48px 20px 28px; }
		.top {
			grid-template-columns: 1fr;
			gap: 36px;
		}
	}
</style>
