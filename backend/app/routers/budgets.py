"""Budgets router."""

from fastapi import APIRouter, Depends, HTTPException

from app.database import Database
from app.dependencies import get_current_user, get_database
from app.schemas.budget import (
    BudgetCreate,
    BudgetUpdate,
    BudgetResponse,
    BudgetListResponse,
)
from app.schemas.common import SuccessResponse


router = APIRouter(prefix="/budgets", tags=["Budgets"])


@router.get("", response_model=BudgetListResponse)
async def list_budgets(
    category_id: str | None = None,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """List all budgets for the user, optionally filtered by category."""
    budgets = db.get_budgets(user["id"], category_id=category_id)
    return BudgetListResponse(
        items=[BudgetResponse(**budget) for budget in budgets],
        total=len(budgets),
    )


@router.post("", response_model=BudgetResponse, status_code=201)
async def create_budget(
    budget: BudgetCreate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Create a new budget."""
    budget_data = {
        **budget.model_dump(),
        "user_id": user["id"],
    }
    created = db.create_budget(budget_data)
    return BudgetResponse(**created)


@router.patch("/{budget_id}", response_model=BudgetResponse)
async def update_budget(
    budget_id: str,
    budget: BudgetUpdate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Update a budget."""
    # Get existing budget
    existing = db.client.table("budgets").select("*").eq("id", budget_id).execute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Budget not found")

    # Check ownership
    if existing.data[0]["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized to update this budget")

    # Update
    update_data = budget.model_dump(exclude_unset=True)
    result = db.client.table("budgets").update(update_data).eq("id", budget_id).execute()

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to update budget")

    return BudgetResponse(**result.data[0])


@router.delete("/{budget_id}", response_model=SuccessResponse)
async def delete_budget(
    budget_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Delete a budget."""
    # Get existing budget
    existing = db.client.table("budgets").select("*").eq("id", budget_id).execute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Budget not found")

    # Check ownership
    if existing.data[0]["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized to delete this budget")

    # Delete
    db.client.table("budgets").delete().eq("id", budget_id).execute()
    return SuccessResponse(message="Budget deleted successfully")
