# AI Categorization Service Architecture

## Overview

The categorization service uses AI to automatically categorize financial transactions into appropriate categories and subcategories. It supports multiple AI providers through an interchangeable interface.

## Architecture

### Abstract Base Class Pattern

```
BaseCategorizationService (ABC)
├── ClaudeCategorizationService (Anthropic)
└── OpenRouterCategorizationService (OpenRouter)
```

The system uses an abstract base class (`BaseCategorizationService`) that defines:
- Common logic for building prompts and processing results
- Abstract method `_call_ai_model()` that each provider implements
- Single `categorize_transactions()` method used by all providers

### Benefits

1. **Easy to swap providers** - Change `CATEGORIZATION_PROVIDER` env var
2. **Consistent behavior** - All providers use same prompt and processing logic
3. **Easy to add new providers** - Just implement `_call_ai_model()` method
4. **Cost optimization** - Use cheaper models for development, Claude for production

## Providers

### 1. Claude (Anthropic) - Production

**Best for:**
- Production use
- High accuracy requirements
- Complex categorization scenarios

**Configuration:**
```bash
CATEGORIZATION_PROVIDER=claude
ANTHROPIC_API_KEY=sk-ant-...
CLAUDE_MODEL=claude-3-5-sonnet-20241022
```

**Pros:**
- Best accuracy
- Reliable JSON output
- Strong reasoning capabilities

**Cons:**
- Higher cost (~$3 per million input tokens)

### 2. OpenRouter - Development/Budget

**Best for:**
- Development and testing
- Budget-conscious deployments
- Access to multiple models via single API

**Configuration:**
```bash
CATEGORIZATION_PROVIDER=openrouter
OPENROUTER_API_KEY=sk-or-...
OPENROUTER_MODEL=meta-llama/llama-3.1-8b-instruct:free
```

**Pros:**
- Free tier available
- Access to 300+ models
- Can use Claude via OpenRouter
- Lower cost for non-Claude models

**Cons:**
- Free models may have lower accuracy
- Rate limits on free tier
- Response quality varies by model

## How It Works

### 1. Transaction Collection
- Fetches uncategorized transactions (or specific IDs if provided)
- Limits to 200 transactions per batch to avoid token overflow

### 2. Context Building
- Builds category tree context (all available categories + subcategories)
- Builds transaction context (ID, amount, description, payee)

### 3. Prompt Generation
- Generates consistent prompt across all providers
- Requests JSON response with structured format:
  ```json
  [
    {
      "transaction_id": "...",
      "category_id": "...",
      "subcategory_id": "...",
      "confidence": 0.95,
      "reasoning": "..."
    }
  ]
  ```

### 4. AI Model Call
- Provider-specific implementation calls AI model
- Returns raw text response

### 5. Response Processing
- Parses JSON response
- Applies categorizations to database
- Returns results with success/failure counts

## Adding a New Provider

To add a new AI provider:

1. Create new class inheriting from `BaseCategorizationService`
2. Implement `_call_ai_model(prompt: str) -> str` method
3. Add provider config to `Settings` in `app/config.py`
4. Add case to factory function in `get_categorization_service()`

Example:

```python
class NewProviderCategorizationService(BaseCategorizationService):
    """Categorization service using New Provider."""

    def __init__(self, db: Database, api_key: str, model: str = "default-model"):
        super().__init__(db)
        from new_provider import Client
        self.client = Client(api_key=api_key)
        self.model = model

    def _call_ai_model(self, prompt: str) -> str:
        """Call New Provider API and return response text."""
        response = self.client.chat.create(
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
        )
        return response.text
```

## Performance Considerations

### Token Usage
- Each batch processes up to 200 transactions
- Estimated tokens per request: ~2,000-4,000 (depending on category count)
- Response tokens: ~1,000-2,000 for 200 transactions

### Cost Comparison (per 1,000 transactions)

**Claude 3.5 Sonnet:**
- Input: ~10K tokens × $3/M = $0.03
- Output: ~5K tokens × $15/M = $0.075
- **Total: ~$0.10 per 1,000 transactions**

**OpenRouter (Free Models):**
- **Cost: $0** (with rate limits)

**OpenRouter (Claude via OpenRouter):**
- Similar to direct Claude pricing
- Slight markup (~10-20%)

### Rate Limits
- **Claude Direct**: 50,000 tokens/min (Tier 1)
- **OpenRouter Free**: 20 requests/min, 200/day
- **OpenRouter Paid**: Varies by model and payment tier

## Error Handling

The service handles:
- Invalid JSON responses (raises exception)
- Missing API keys (raises ValueError)
- Invalid provider configuration (raises ValueError)
- Individual transaction categorization failures (continues processing)
- Network errors (raises exception with details)

## Future Enhancements

Potential improvements:
1. **Batch optimization** - Dynamically adjust batch size based on token limits
2. **Caching** - Cache category/subcategory pairs to reduce repeat processing
3. **Confidence thresholds** - Only apply categorizations above certain confidence
4. **Learning from user edits** - Track manual overrides to improve prompts
5. **Multi-model ensemble** - Use multiple models and vote on categorizations
6. **Async processing** - Process large batches in background
7. **Custom prompts** - Allow users to customize categorization logic
