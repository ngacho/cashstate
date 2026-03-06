<section class="cta" id="get-started">
	<div class="inner">
		<div class="card">
			<h2>Get started today.</h2>
			<p>Join thousands of people taking control of their finances.</p>
			<a href="/app-store" class="btn" aria-label="Download on the App Store">
				Download for free
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
			</a>
		</div>
	</div>
</section>

<style>
	.cta {
		padding: 100px 24px;
		background: var(--bg-alt);
	}

	.inner {
		max-width: var(--container);
		margin: 0 auto;
	}

	.card {
		background: var(--text-primary);
		color: var(--bg);
		border-radius: 32px;
		padding: 80px 48px;
		text-align: center;
	}

	h2 {
		font-size: clamp(36px, 5vw, 56px);
		font-weight: 700;
		letter-spacing: -0.03em;
		line-height: 1.1;
		margin-bottom: 16px;
	}

	p {
		font-size: 18px;
		opacity: 0.6;
		margin-bottom: 40px;
		max-width: 500px;
		margin-left: auto;
		margin-right: auto;
	}

	.btn {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 14px 28px;
		background: var(--bg);
		color: var(--text-primary);
		border-radius: 100px;
		font-size: 15px;
		font-weight: 600;
		transition: opacity 0.2s;
	}

	.btn:hover {
		opacity: 0.9;
	}

	@media (max-width: 640px) {
		.cta { padding: 60px 16px; }
		.card { padding: 48px 24px; border-radius: 24px; }
	}
</style>
