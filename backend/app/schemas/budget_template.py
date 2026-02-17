"""Budget template schemas."""

from datetime import datetime
from pydantic import BaseModel, Field


# ============================================================================
# Budget Template Schemas
# ============================================================================


class BudgetTemplateBase(BaseModel):
    """Base budget template fields."""

    name: str = Field(..., min_length=1, max_length=100, description="Template name (e.g., 'Regular Budget')")
    total_amount: float = Field(default=0, ge=0, description="Total budget amount")
    is_default: bool = Field(default=False, description="Set as default template")
    account_ids: list[str] = Field(
        default_factory=list,
        description="Account IDs to track. Empty = all accounts",
    )


class BudgetTemplateCreate(BudgetTemplateBase):
    """Create a new budget template."""

    pass


class BudgetTemplateUpdate(BaseModel):
    """Update an existing budget template."""

    name: str | None = Field(None, min_length=1, max_length=100)
    total_amount: float | None = Field(None, gt=0)
    is_default: bool | None = None
    account_ids: list[str] | None = None


class BudgetTemplateResponse(BudgetTemplateBase):
    """Budget template response with metadata."""

    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime


class BudgetTemplateListResponse(BaseModel):
    """List of budget templates."""

    items: list[BudgetTemplateResponse]
    total: int


# ============================================================================
# Budget Category Schemas
# ============================================================================


class CategoryBudgetBase(BaseModel):
    """Base category budget fields."""

    category_id: str = Field(..., description="Category ID")
    amount: float = Field(..., ge=0, description="Budget amount for this category")


class CategoryBudgetCreate(CategoryBudgetBase):
    """Create a category budget."""

    pass


class CategoryBudgetUpdate(BaseModel):
    """Update a category budget."""

    amount: float = Field(..., ge=0)


class CategoryBudgetResponse(CategoryBudgetBase):
    """Category budget response."""

    id: str
    template_id: str
    created_at: datetime
    updated_at: datetime


# ============================================================================
# Budget Subcategory Schemas
# ============================================================================


class SubcategoryBudgetBase(BaseModel):
    """Base subcategory budget fields."""

    subcategory_id: str = Field(..., description="Subcategory ID")
    amount: float = Field(..., ge=0, description="Budget amount for this subcategory")


class SubcategoryBudgetCreate(SubcategoryBudgetBase):
    """Create a subcategory budget."""

    pass


class SubcategoryBudgetUpdate(BaseModel):
    """Update a subcategory budget."""

    amount: float = Field(..., ge=0)


class SubcategoryBudgetResponse(SubcategoryBudgetBase):
    """Subcategory budget response."""

    id: str
    template_id: str
    created_at: datetime
    updated_at: datetime


# ============================================================================
# Budget Period Schemas
# ============================================================================


class BudgetPeriodBase(BaseModel):
    """Base budget period fields."""

    template_id: str = Field(..., description="Template to apply for this month")
    period_month: str = Field(..., description="Month in YYYY-MM format (e.g., '2026-02')")


class BudgetPeriodCreate(BudgetPeriodBase):
    """Create a budget period (apply template to month)."""

    pass


class BudgetPeriodResponse(BudgetPeriodBase):
    """Budget period response."""

    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime


class BudgetPeriodListResponse(BaseModel):
    """List of budget periods."""

    items: list[BudgetPeriodResponse]
    total: int


# ============================================================================
# Template with Categories (for detailed view)
# ============================================================================


class TemplateWithCategories(BudgetTemplateResponse):
    """Template with category and subcategory budgets."""

    categories: list[CategoryBudgetResponse] = []
    subcategories: list[SubcategoryBudgetResponse] = []
