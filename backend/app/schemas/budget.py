"""Budget schemas."""

from datetime import datetime
from pydantic import BaseModel, Field


# ============================================================================
# Budget Schemas
# ============================================================================


class BudgetCreate(BaseModel):
    """Create a new budget."""

    name: str = Field(..., min_length=1, max_length=100)
    is_default: bool = Field(default=False)
    emoji: str | None = Field(default="💰", max_length=10)
    color: str | None = Field(default="#00A699", max_length=20)
    account_ids: list[str] = Field(
        default_factory=list,
        description="Account IDs to link. Empty = no accounts linked.",
    )


class BudgetUpdate(BaseModel):
    """Update an existing budget."""

    name: str | None = Field(None, min_length=1, max_length=100)
    is_default: bool | None = None
    emoji: str | None = Field(None, max_length=10)
    color: str | None = Field(None, max_length=20)


class BudgetResponse(BaseModel):
    """Budget response."""

    id: str
    user_id: str
    name: str
    is_default: bool
    emoji: str | None = None
    color: str | None = None
    created_at: datetime
    updated_at: datetime


class BudgetListResponse(BaseModel):
    """List of budgets."""

    items: list[BudgetResponse]
    total: int


# ============================================================================
# Budget Account Schemas
# ============================================================================


class BudgetAccountAdd(BaseModel):
    """Add an account to a budget."""

    account_id: str


class BudgetAccountResponse(BaseModel):
    """Budget account response."""

    budget_id: str
    account_id: str
    account_name: str
    balance: float
    created_at: datetime


class BudgetAccountListResponse(BaseModel):
    """List of budget accounts."""

    items: list[BudgetAccountResponse]
    total: int


# ============================================================================
# Budget Line Item Schemas
# ============================================================================


class BudgetLineItemCreate(BaseModel):
    """Create a budget line item."""

    category_id: str
    subcategory_id: str | None = None
    amount: float = Field(..., ge=0)


class BudgetLineItemUpdate(BaseModel):
    """Update a budget line item amount."""

    amount: float = Field(..., ge=0)


class BudgetLineItemResponse(BaseModel):
    """Budget line item response."""

    id: str
    budget_id: str
    category_id: str
    subcategory_id: str | None
    amount: float
    created_at: datetime
    updated_at: datetime


class BudgetLineItemListResponse(BaseModel):
    """List of budget line items."""

    items: list[BudgetLineItemResponse]
    total: int


# ============================================================================
# Budget Month Schemas
# ============================================================================


class BudgetMonthCreate(BaseModel):
    """Assign a budget to a specific month."""

    budget_id: str
    month: str = Field(..., description="Month in YYYY-MM format (e.g., '2026-02')")


class BudgetMonthResponse(BaseModel):
    """Budget month response."""

    id: str
    budget_id: str
    user_id: str
    month: str  # Returned as "YYYY-MM" string
    created_at: datetime


class BudgetMonthListResponse(BaseModel):
    """List of budget months."""

    items: list[BudgetMonthResponse]
    total: int


# ============================================================================
# Budget Summary Schemas
# ============================================================================


class BudgetSummaryLineItem(BaseModel):
    """A single line item in the budget summary with actuals."""

    id: str  # line item ID (for PATCH/DELETE)
    budget_id: str
    category_id: str
    subcategory_id: str | None
    amount: float  # budgeted amount
    spent: float  # actual spending (computed)
    remaining: float  # amount - spent


class UnbudgetedCategory(BaseModel):
    """A category with spending but no line item in the budget."""

    category_id: str
    spent: float


class BudgetSummary(BaseModel):
    """Full budget summary for a month."""

    budget_id: str
    budget_name: str
    month: str  # "YYYY-MM"
    total_budgeted: float
    total_spent: float
    line_items: list[BudgetSummaryLineItem]
    unbudgeted_categories: list[UnbudgetedCategory]
    subcategory_spending: dict[str, float]  # subcategory_id → amount spent
    uncategorized_spending: float  # spending with no category assigned
