<footer>
	<div class="footer-inner">
		<div class="footer-brand">
			<div class="logo">
				<span class="logo-icon">$</span>
				<span class="logo-text">CashState</span>
			</div>
			<p>Know the state of your cash.</p>
		</div>

		<div class="footer-links">
			<div class="link-group">
				<h4>Product</h4>
				<a href="#features">Features</a>
				<a href="#how-it-works">How it works</a>
				<a href="#faq">FAQ</a>
			</div>
			<div class="link-group">
				<h4>Company</h4>
				<a href="#about">About</a>
				<a href="#blog">Blog</a>
				<a href="#careers">Careers</a>
			</div>
			<div class="link-group">
				<h4>Legal</h4>
				<a href="#privacy">Privacy</a>
				<a href="#terms">Terms</a>
			</div>
		</div>
	</div>

	<div class="footer-bottom">
		<p>&copy; {new Date().getFullYear()} CashState. All rights reserved.</p>
	</div>
</footer>

<style>
	footer {
		padding: 4rem 2rem 2rem;
		background: var(--color-background);
		border-top: 1px solid var(--color-border);
	}

	.footer-inner {
		max-width: 1100px;
		margin: 0 auto;
		display: flex;
		justify-content: space-between;
		gap: 3rem;
		margin-bottom: 3rem;
	}

	.footer-brand {
		max-width: 250px;
	}

	.logo {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-weight: 800;
		font-size: 1.2rem;
		color: var(--color-dark);
		margin-bottom: 0.75rem;
	}

	.logo-icon {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 32px;
		height: 32px;
		background: var(--color-primary);
		color: var(--color-white);
		border-radius: 8px;
		font-weight: 900;
		font-size: 1rem;
	}

	.footer-brand p {
		font-size: 0.9rem;
		color: var(--color-text-light);
	}

	.footer-links {
		display: flex;
		gap: 4rem;
	}

	.link-group {
		display: flex;
		flex-direction: column;
		gap: 0.6rem;
	}

	.link-group h4 {
		font-size: 0.85rem;
		font-weight: 700;
		color: var(--color-dark);
		margin-bottom: 0.3rem;
	}

	.link-group a {
		font-size: 0.85rem;
		color: var(--color-text-light);
		transition: color 0.2s;
	}

	.link-group a:hover {
		color: var(--color-primary);
	}

	.footer-bottom {
		max-width: 1100px;
		margin: 0 auto;
		padding-top: 2rem;
		border-top: 1px solid var(--color-border);
	}

	.footer-bottom p {
		font-size: 0.8rem;
		color: var(--color-text-light);
	}

	@media (max-width: 768px) {
		.footer-inner {
			flex-direction: column;
		}

		.footer-links {
			gap: 2rem;
		}
	}
</style>
