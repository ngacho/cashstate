<section class="cta" id="get-started">
	<div class="inner">
		<div class="card">
			<div class="card-glow"></div>
			<div class="card-content">
				<h2>Get started today.</h2>
				<p>Join thousands of people taking control of their finances. Free forever.</p>
				<a href="/app-store" class="btn" aria-label="Download on the App Store">
					<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
						<path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
					</svg>
					Download for free
				</a>
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
		font-family: var(--font-serif);
		font-size: clamp(36px, 5vw, 52px);
		font-weight: 400;
		letter-spacing: -0.02em;
		line-height: 1.15;
		margin-bottom: 16px;
	}

	p {
		font-size: 17px;
		opacity: 0.6;
		margin-bottom: 40px;
		max-width: 420px;
		margin-left: auto;
		margin-right: auto;
		line-height: 1.7;
	}

	.btn {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 16px 32px;
		background: var(--bg);
		color: var(--text-primary);
		border-radius: 100px;
		font-size: 15px;
		font-weight: 600;
		transition: opacity 0.2s, transform 0.2s;
	}

	.btn:hover {
		opacity: 0.9;
		transform: translateY(-1px);
	}

	@media (max-width: 640px) {
		.cta { padding: 40px 20px 80px; }
		.card-content { padding: 56px 28px; }
		.card { border-radius: 24px; }
	}
</style>
