"""AI-powered transaction categorization."""

import json
from abc import ABC, abstractmethod
from anthropic import Anthropic
from app.config import get_settings
from app.database import Database


class BaseCategorizationService(ABC):
    """Abstract base class for categorization services."""

    def __init__(self, db: Database):
        self.db = db

    @abstractmethod
    def _call_ai_model(self, prompt: str) -> str:
        """Call the AI model with the given prompt and return response text.

        Args:
            prompt: The categorization prompt

        Returns:
            str: The raw response text from the AI model
        """
        pass

    def _build_categories_context(self, user_id: str) -> str:
        """Build context of available categories and subcategories."""
        categories = self.db.get_categories(user_id)
        subcategories = self.db.get_subcategories()

        # Group subcategories by category
        subcats_by_category = {}
        for sub in subcategories:
            cat_id = sub["category_id"]
            if cat_id not in subcats_by_category:
                subcats_by_category[cat_id] = []
            subcats_by_category[cat_id].append(sub)

        # Build context string
        context_lines = ["Available categories and subcategories:\n"]
        for cat in categories:
            context_lines.append(f"- {cat['name']} (ID: {cat['id']})")
            if cat["id"] in subcats_by_category:
                for sub in subcats_by_category[cat["id"]]:
                    context_lines.append(f"  - {sub['name']} (ID: {sub['id']})")

        return "\n".join(context_lines)

    def _build_transactions_context(self, transactions: list[dict]) -> str:
        """Build context of transactions to categorize."""
        lines = ["Transactions to categorize:\n"]
        for txn in transactions:
            lines.append(
                f"ID: {txn['id']} | Amount: ${txn['amount']:.2f} | "
                f"Description: {txn['description']} | "
                f"Payee: {txn.get('payee', 'N/A')}"
            )
        return "\n".join(lines)

    def _build_prompt(self, categories_context: str, transactions_context: str) -> str:
        """Build the categorization prompt."""
        return f"""You are a financial transaction categorization assistant. Your task is to categorize transactions into the appropriate category and subcategory.

{categories_context}

{transactions_context}

For each transaction, determine the most appropriate category and subcategory based on the description, payee, and amount.

Respond with a JSON array of objects, where each object has:
- transaction_id: The transaction ID
- category_id: The category ID (or null if uncertain)
- subcategory_id: The subcategory ID (or null if uncertain/not applicable)
- confidence: A number between 0 and 1 indicating confidence
- reasoning: Brief explanation of why this categorization was chosen

Example response format:
[
  {{
    "transaction_id": "abc-123",
    "category_id": "cat-food-id",
    "subcategory_id": "sub-restaurants-id",
    "confidence": 0.95,
    "reasoning": "Transaction at Chipotle, clearly a restaurant expense"
  }},
  ...
]

Only respond with the JSON array, no other text."""

    def categorize_transactions(
        self, user_id: str, transaction_ids: list[str] | None = None, force: bool = False
    ) -> dict:
        """Categorize transactions using AI.

        Args:
            user_id: User ID to categorize transactions for
            transaction_ids: Specific transaction IDs to categorize (None = all uncategorized)
            force: If True, re-categorize even if already categorized

        Returns:
            dict with categorization results
        """
        # Get transactions to categorize
        if transaction_ids:
            # Get specific transactions
            transactions = []
            for txn_id in transaction_ids:
                txn = self.db.get_simplefin_transaction_by_id(txn_id)
                if txn and txn["user_id"] == user_id:
                    transactions.append(txn)
        else:
            # Get all uncategorized transactions (or all if force=True)
            all_txns = self.db.get_user_simplefin_transactions(
                user_id=user_id, limit=200  # Limit to avoid token overflow
            )
            if force:
                transactions = all_txns
            else:
                transactions = [txn for txn in all_txns if txn.get("category_id") is None]

        if not transactions:
            return {
                "categorized_count": 0,
                "failed_count": 0,
                "results": [],
            }

        # Build context
        categories_context = self._build_categories_context(user_id)
        transactions_context = self._build_transactions_context(transactions)
        prompt = self._build_prompt(categories_context, transactions_context)

        # Call AI model
        try:
            response_text = self._call_ai_model(prompt)
            categorizations = json.loads(response_text)

            # Apply categorizations
            results = []
            categorized_count = 0
            failed_count = 0

            for cat in categorizations:
                try:
                    txn_id = cat["transaction_id"]
                    category_id = cat.get("category_id")
                    subcategory_id = cat.get("subcategory_id")

                    # Update transaction
                    updated = self.db.update_transaction_category(
                        transaction_id=txn_id,
                        category_id=category_id,
                        subcategory_id=subcategory_id,
                    )

                    if updated:
                        categorized_count += 1
                        results.append({
                            "transaction_id": txn_id,
                            "category_id": category_id,
                            "subcategory_id": subcategory_id,
                            "confidence": cat.get("confidence", 0.0),
                            "reasoning": cat.get("reasoning"),
                        })
                    else:
                        failed_count += 1
                except Exception as e:
                    failed_count += 1
                    print(f"Failed to categorize transaction {cat.get('transaction_id')}: {e}")

            return {
                "categorized_count": categorized_count,
                "failed_count": failed_count,
                "results": results,
            }

        except Exception as e:
            raise Exception(f"AI categorization failed: {str(e)}")


class ClaudeCategorizationService(BaseCategorizationService):
    """Categorization service using Claude (Anthropic)."""

    def __init__(self, db: Database, api_key: str, model: str = "claude-3-5-sonnet-20241022"):
        super().__init__(db)
        self.client = Anthropic(api_key=api_key)
        self.model = model

    def _call_ai_model(self, prompt: str) -> str:
        """Call Claude API and return response text."""
        message = self.client.messages.create(
            model=self.model,
            max_tokens=4096,
            messages=[{"role": "user", "content": prompt}],
        )
        return message.content[0].text


class OpenRouterCategorizationService(BaseCategorizationService):
    """Categorization service using OpenRouter."""

    def __init__(
        self, db: Database, api_key: str, model: str = "meta-llama/llama-3.1-8b-instruct:free"
    ):
        super().__init__(db)
        try:
            from openrouter import OpenRouter
        except ImportError:
            raise ImportError(
                "openrouter package not installed. Install with: uv add openrouter"
            )
        self.client = OpenRouter(api_key=api_key)
        self.model = model

    def _call_ai_model(self, prompt: str) -> str:
        """Call OpenRouter API and return response text."""
        response = self.client.chat.send(
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
        )
        return response.choices[0].message.content


def get_categorization_service(db: Database) -> BaseCategorizationService:
    """Get categorization service instance based on configuration.

    Returns:
        BaseCategorizationService: Either Claude or OpenRouter service based on config

    Raises:
        ValueError: If required API keys are missing or provider is invalid
    """
    settings = get_settings()

    # Determine which provider to use
    provider = getattr(settings, "categorization_provider", "claude").lower()

    if provider == "claude":
        api_key = getattr(settings, "anthropic_api_key", None)
        if not api_key:
            raise ValueError("ANTHROPIC_API_KEY not configured in settings")
        model = getattr(settings, "claude_model", "claude-3-5-sonnet-20241022")
        return ClaudeCategorizationService(db=db, api_key=api_key, model=model)

    elif provider == "openrouter":
        api_key = getattr(settings, "openrouter_api_key", None)
        if not api_key:
            raise ValueError("OPENROUTER_API_KEY not configured in settings")
        model = getattr(
            settings, "openrouter_model", "meta-llama/llama-3.1-8b-instruct:free"
        )
        return OpenRouterCategorizationService(db=db, api_key=api_key, model=model)

    else:
        raise ValueError(
            f"Invalid categorization provider: {provider}. Must be 'claude' or 'openrouter'"
        )
