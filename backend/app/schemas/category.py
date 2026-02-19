"""Category and subcategory schemas."""

from datetime import datetime
from pydantic import BaseModel, Field


# ============================================================================
# Category Schemas
# ============================================================================


class CategoryBase(BaseModel):
    """Base category fields."""

    name: str = Field(..., min_length=1, max_length=100)
    icon: str | None = Field(
        None, description="Emoji character (e.g., '🍽️') - cross-platform"
    )
    color: str | None = Field(None, description="Hex color code (e.g., '#FF5733')")
    display_order: int = Field(default=0, description="Display order for sorting")


class CategoryCreate(CategoryBase):
    """Create a new category."""

    pass


class CategoryUpdate(BaseModel):
    """Update an existing category."""

    name: str | None = Field(None, min_length=1, max_length=100)
    icon: str | None = None
    color: str | None = None
    display_order: int | None = None


class CategoryResponse(CategoryBase):
    """Category response with metadata."""

    id: str
    user_id: str | None  # None for system categories
    is_default: bool
    created_at: datetime
    updated_at: datetime


class CategoryListResponse(BaseModel):
    """List of categories."""

    items: list[CategoryResponse]
    total: int


# ============================================================================
# Subcategory Schemas
# ============================================================================


class SubcategoryBase(BaseModel):
    """Base subcategory fields."""

    category_id: str = Field(..., description="Parent category ID")
    name: str = Field(..., min_length=1, max_length=100)
    icon: str | None = Field(None, description="Emoji character - cross-platform")
    display_order: int = Field(default=0, description="Display order within category")


class SubcategoryCreate(BaseModel):
    """Create a new subcategory (category_id comes from URL path)."""

    name: str = Field(..., min_length=1, max_length=100)
    icon: str | None = Field(None, description="Emoji character - cross-platform")
    display_order: int = Field(default=0, description="Display order within category")


class SubcategoryUpdate(BaseModel):
    """Update an existing subcategory."""

    category_id: str | None = None
    name: str | None = Field(None, min_length=1, max_length=100)
    icon: str | None = None
    display_order: int | None = None


class SubcategoryResponse(SubcategoryBase):
    """Subcategory response with metadata."""

    id: str
    user_id: str | None  # None for system subcategories
    is_default: bool
    created_at: datetime
    updated_at: datetime


class SubcategoryListResponse(BaseModel):
    """List of subcategories."""

    items: list[SubcategoryResponse]
    total: int


# ============================================================================
# Category with Subcategories
# ============================================================================


class CategoryWithSubcategories(CategoryResponse):
    """Category with nested subcategories."""

    subcategories: list[SubcategoryResponse] = []


class CategoriesTreeResponse(BaseModel):
    """Tree structure of categories with subcategories."""

    items: list[CategoryWithSubcategories]
    total: int


# ============================================================================
# Categorization Rule Schemas
# ============================================================================


class CategorizationRuleCreate(BaseModel):
    """Create a new categorization rule."""

    match_field: str = Field(
        ...,
        description="Field to match against: 'payee', 'description', or 'memo'",
    )
    match_value: str = Field(
        ..., min_length=1, description="Case-insensitive substring to match"
    )
    category_id: str = Field(..., description="Category to assign when rule matches")
    subcategory_id: str | None = Field(
        None, description="Optional subcategory to assign"
    )


class CategorizationRuleResponse(BaseModel):
    """Categorization rule response."""

    id: str
    user_id: str
    match_field: str
    match_value: str
    category_id: str
    subcategory_id: str | None
    created_at: datetime


class CategorizationRuleListResponse(BaseModel):
    """List of categorization rules."""

    items: list[CategorizationRuleResponse]
    total: int


# ============================================================================
# Manual Categorization
# ============================================================================


class ManualCategorizationRequest(BaseModel):
    """Manually categorize a transaction."""

    category_id: str | None = Field(
        None, description="Category to assign (null to clear)"
    )
    subcategory_id: str | None = Field(
        None, description="Subcategory to assign (null to clear)"
    )
    create_rule: bool = Field(
        default=False,
        description="Create a rule based on this transaction's payee for future auto-categorization",
    )


# ============================================================================
# Categorization Request/Response
# ============================================================================


class CategorizationRequest(BaseModel):
    """Request to categorize transactions with AI."""

    transaction_ids: list[str] | None = Field(
        None,
        description="Specific transaction IDs to categorize. If None, categorizes all uncategorized transactions.",
    )
    force: bool = Field(
        default=False,
        description="If True, re-categorize even if already categorized",
    )


class TransactionCategorization(BaseModel):
    """Single transaction categorization result."""

    transaction_id: str
    category_id: str | None
    subcategory_id: str | None
    confidence: float = Field(..., ge=0.0, le=1.0, description="Confidence score (0-1)")
    reasoning: str | None = Field(None, description="AI reasoning for categorization")


class CategorizationResponse(BaseModel):
    """Response from AI categorization."""

    categorized_count: int
    failed_count: int
    results: list[TransactionCategorization]


# ============================================================================
# Onboarding / Seed Defaults
# ============================================================================


class SeedDefaultsRequest(BaseModel):
    """Request to seed default categories with budget allocation."""

    monthly_budget: float = Field(
        ...,
        gt=0,
        description="Total monthly budget to distribute across categories (e.g., 3000.00)",
    )
    account_ids: list[str] = Field(
        default_factory=list,
        description="Account IDs to track for budgets. Empty = all accounts",
    )


class SeedDefaultsResponse(BaseModel):
    """Response from seeding default categories."""

    categories_created: int
    subcategories_created: int
    budgets_created: int
    monthly_budget: float
    budget_per_category: float
