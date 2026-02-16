"""Budget schemas."""

from datetime import datetime
from pydantic import BaseModel, Field


class BudgetBase(BaseModel):
    """Base budget fields."""

    category_id: str = Field(..., description="Category this budget applies to")
    amount: float = Field(..., gt=0, description="Budget amount")
    period: str = Field(
        default="monthly",
        description="Budget period: weekly, monthly, yearly",
    )


class BudgetCreate(BudgetBase):
    """Create a new budget."""

    pass


class BudgetUpdate(BaseModel):
    """Update an existing budget."""

    category_id: str | None = None
    amount: float | None = Field(None, gt=0)
    period: str | None = None


class BudgetResponse(BudgetBase):
    """Budget response with metadata."""

    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime


class BudgetListResponse(BaseModel):
    """List of budgets."""

    items: list[BudgetResponse]
    total: int
