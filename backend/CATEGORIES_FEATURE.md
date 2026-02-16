# Categories & AI Categorization Feature

## Overview

Added comprehensive transaction categorization support with AI-powered auto-categorization using Claude.

## What We Built

### 1. Database Schema (`supabase/migrations/`)

#### New Tables

**`categories`** - Top-level categories (Food, Transportation, etc.)
- `id` - UUID primary key
- `user_id` - NULL for system categories, user UUID for custom categories
- `name` - Category name
- `icon` - SF Symbol name (for iOS)
- `color` - Hex color code
- `is_system` - Boolean (system vs user-created)
- `display_order` - Sort order
- RLS policies: Users can view system categories + their own, can only modify their own

**`subcategories`** - Subcategories under parent categories
- `id` - UUID primary key
- `category_id` - FK to parent category
- `user_id` - NULL for system, user UUID for custom
- `name` - Subcategory name
- `icon` - SF Symbol name
- `is_system` - Boolean
- `display_order` - Sort order within category
- RLS policies: Same as categories

**`simplefin_transactions` (updated)**
- Added `category_id` - FK to categories (nullable)
- Added `subcategory_id` - FK to subcategories (nullable)
- Added indexes for efficient filtering

#### Migration Files

- **`001_complete_schema.sql`** - Complete schema from scratch (includes categories)
- **`002_add_categories.sql`** - Add categories to existing database
- **`README.md`** - Migration instructions

### 2. Backend Models (`app/schemas/category.py`)

**Request/Response Schemas:**
- `CategoryCreate` / `CategoryUpdate` / `CategoryResponse`
- `SubcategoryCreate` / `SubcategoryUpdate` / `SubcategoryResponse`
- `CategoryWithSubcategories` - Category with nested subcategories
- `CategoriesTreeResponse` - Full category tree
- `CategorizationRequest` - AI categorization request
- `CategorizationResponse` - AI categorization results

**Updated:**
- `TransactionResponse` - Added `category_id` and `subcategory_id` fields

### 3. Database Methods (`app/database.py`)

Added methods to the `Database` class:
- `get_categories(user_id)` - Get all visible categories
- `get_category_by_id(category_id)` - Get single category
- `create_category(category_data)` - Create user category
- `update_category(category_id, data)` - Update category
- `delete_category(category_id)` - Delete category
- `get_subcategories(category_id)` - Get subcategories
- `get_subcategory_by_id(subcategory_id)` - Get single subcategory
- `create_subcategory(subcategory_data)` - Create subcategory
- `update_subcategory(subcategory_id, data)` - Update subcategory
- `delete_subcategory(subcategory_id)` - Delete subcategory
- `update_transaction_category(transaction_id, category_id, subcategory_id)` - Categorize transaction

### 4. API Endpoints (`app/routers/categories.py`)

#### Categories CRUD
- `GET /categories` - List all categories (system + user's own)
- `GET /categories/tree` - Get categories with nested subcategories
- `GET /categories/{id}` - Get single category
- `POST /categories` - Create new user category
- `PATCH /categories/{id}` - Update user category
- `DELETE /categories/{id}` - Delete user category

#### Subcategories CRUD
- `GET /categories/{category_id}/subcategories` - List subcategories for a category
- `POST /categories/{category_id}/subcategories` - Create subcategory
- `GET /categories/subcategories/{id}` - Get single subcategory
- `PATCH /categories/subcategories/{id}` - Update subcategory
- `DELETE /categories/subcategories/{id}` - Delete subcategory

#### AI Categorization
- `POST /categories/ai/categorize` - Categorize transactions using Claude AI
  - Request body:
    ```json
    {
      "transaction_ids": ["uuid1", "uuid2"],  // Optional, null = all uncategorized
      "force": false  // If true, re-categorize already categorized transactions
    }
    ```
  - Response:
    ```json
    {
      "categorized_count": 10,
      "failed_count": 0,
      "results": [
        {
          "transaction_id": "uuid",
          "category_id": "category-uuid",
          "subcategory_id": "subcategory-uuid",
          "confidence": 0.95,
          "reasoning": "Transaction at Chipotle, clearly a restaurant expense"
        }
      ]
    }
    ```

### 5. AI Categorization Service (`app/services/categorization_service.py`)

**Features:**
- Uses Claude 3.5 Sonnet for intelligent categorization
- Analyzes transaction description, payee, and amount
- Returns category, subcategory, confidence score, and reasoning
- Can categorize specific transactions or all uncategorized
- Respects existing categorizations unless `force=True`

**How it works:**
1. Fetches available categories and subcategories
2. Fetches transactions to categorize
3. Builds context prompt for Claude with categories and transactions
4. Claude returns JSON array with categorization decisions
5. Applies categorizations to database

### 6. Configuration (`app/config.py`)

Added new environment variable:
- `ANTHROPIC_API_KEY` (optional) - Anthropic API key for Claude AI

### 7. Dependencies (`pyproject.toml`)

Added:
- `anthropic` - Anthropic Python SDK for Claude API
- `cryptography` - For encryption (already present)

### 8. Tests (`tests/test_complete_simplefin.py`)

Added test cases:
- `test_14_create_category` - Create a custom category
- `test_15_list_categories` - List all categories
- `test_16_create_subcategory` - Create subcategory under category
- `test_17_get_categories_tree` - Get categories with nested subcategories
- `test_18_categorize_transaction` - Manually categorize a transaction

## Setup Instructions

### 1. Run Database Migration

**For new databases:**
```sql
-- Run in Supabase SQL Editor
-- File: supabase/migrations/001_complete_schema.sql
```

**For existing databases:**
```sql
-- Run in Supabase SQL Editor
-- File: supabase/migrations/002_add_categories.sql
```

### 2. Set Environment Variable

Add to your `.env` file:
```bash
ANTHROPIC_API_KEY=sk-ant-api03-...  # Get from https://console.anthropic.com
```

**Note:** AI categorization is optional. The API works without it, but the `/categories/ai/categorize` endpoint will return an error if the key is not set.

### 3. Install Dependencies

```bash
uv sync
```

### 4. Run Tests

```bash
# Run all tests
uv run pytest tests/test_complete_simplefin.py -v

# Run only category tests
uv run pytest tests/test_complete_simplefin.py -v -k "test_14 or test_15 or test_16 or test_17 or test_18"
```

## Usage Examples

### Create a Category

```bash
curl -X POST http://localhost:8000/app/v1/categories \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Food & Dining",
    "icon": "fork.knife",
    "color": "#FF5733",
    "display_order": 1
  }'
```

### Get Categories Tree

```bash
curl -X GET http://localhost:8000/app/v1/categories/tree \
  -H "Authorization: Bearer $TOKEN"
```

### AI Categorize All Uncategorized Transactions

```bash
curl -X POST http://localhost:8000/app/v1/categories/ai/categorize \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "transaction_ids": null,
    "force": false
  }'
```

### AI Categorize Specific Transactions

```bash
curl -X POST http://localhost:8000/app/v1/categories/ai/categorize \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "transaction_ids": ["txn-uuid-1", "txn-uuid-2"],
    "force": true
  }'
```

## Next Steps

### Backend
1. **Seed System Categories** - Create a migration to seed common categories (Food, Transportation, Shopping, etc.)
2. **Batch Categorization** - Add background job for periodic auto-categorization
3. **Categorization Rules** - Add user-defined rules for automatic categorization
4. **Analytics** - Add endpoints for spending by category over time

### iOS App
1. **Categories View** - Display categories and subcategories
2. **Transaction Categorization** - Allow users to manually categorize transactions
3. **AI Categorization Button** - Trigger AI categorization from app
4. **Category Management** - Add/edit/delete custom categories
5. **Charts** - Spending breakdown by category
6. **Budget by Category** - Set budgets per category

## Architecture Notes

### Security
- RLS policies ensure users can only modify their own categories
- System categories are read-only for all users
- AI categorization respects user's JWT and RLS policies

### Performance
- Indexes on `category_id` and `subcategory_id` for fast filtering
- Categories cached per request (small dataset)
- AI categorization limited to 200 transactions per request to avoid token overflow

### Scalability
- System categories shared across all users (no duplication)
- User categories stored separately
- Subcategories cascade delete when parent category deleted
- Transactions set to NULL when category deleted (ON DELETE SET NULL)

## API Documentation

Full API documentation available at:
- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

After starting the server, visit these URLs to see interactive API documentation with request/response schemas and try the endpoints.
