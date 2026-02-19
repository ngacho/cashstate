"""Budgets router."""

from fastapi import APIRouter, Depends, HTTPException

from app.database import Database
from app.dependencies import get_current_user, get_database
from app.logging_config import get_logger
from app.schemas.budget import (
    BudgetCreate,
    BudgetUpdate,
    BudgetResponse,
    BudgetListResponse,
    BudgetAccountAdd,
    BudgetAccountResponse,
    BudgetAccountListResponse,
    BudgetLineItemCreate,
    BudgetLineItemUpdate,
    BudgetLineItemResponse,
    BudgetLineItemListResponse,
    BudgetMonthCreate,
    BudgetMonthResponse,
    BudgetMonthListResponse,
    BudgetSummary,
)
from app.schemas.common import SuccessResponse
from app.services.budget_service import get_budget_service


router = APIRouter(prefix="/budgets", tags=["Budgets"])
logger = get_logger("budgets")


# ============================================================================
# Budget Summary (Key endpoint — must be before /{budget_id} to avoid conflict)
# ============================================================================


@router.get("/summary", response_model=BudgetSummary)
async def get_budget_summary(
    month: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Get budget summary for a specific month.

    Resolves the active budget for the month:
    - If user has a budget_months override → uses that budget
    - Otherwise → uses the default budget (is_default=True)
    - If no default → 404

    Returns budget + line items + actuals (spending computed from transactions).
    """
    logger.info(f"[GET /budgets/summary] User: {user['id']}, month: {month}")

    budget_service = get_budget_service(db)
    try:
        summary = budget_service.get_budget_summary(user_id=user["id"], month_str=month)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    if not summary:
        raise HTTPException(
            status_code=404,
            detail="No budget found for this month. Create a default budget first.",
        )

    return BudgetSummary(**summary)


# ============================================================================
# Budget Months (must be before /{budget_id} to avoid route conflict)
# ============================================================================


@router.get("/months", response_model=BudgetMonthListResponse)
async def list_budget_months(
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """List all budget month overrides."""
    months = db.get_budget_months(user["id"])
    items = []
    for m in months:
        # Convert DATE "YYYY-MM-01" → "YYYY-MM" for API
        month_str = str(m["month"])[:7]
        items.append(
            BudgetMonthResponse(
                id=m["id"],
                budget_id=m["budget_id"],
                user_id=m["user_id"],
                month=month_str,
                created_at=m["created_at"],
            )
        )
    return BudgetMonthListResponse(items=items, total=len(items))


@router.post("/months", response_model=BudgetMonthResponse, status_code=201)
async def assign_budget_month(
    request: BudgetMonthCreate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Assign a budget to a specific month (override default)."""
    # Verify budget ownership
    budget = db.get_budget(request.budget_id)
    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found")
    if budget["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Parse and convert month to YYYY-MM-01
    try:
        year, month = request.month.split("-")
        from datetime import date

        month_date = date(int(year), int(month), 1)
    except (ValueError, AttributeError):
        raise HTTPException(
            status_code=400, detail="Invalid month format. Expected YYYY-MM"
        )

    created = db.create_budget_month(
        {
            "budget_id": request.budget_id,
            "user_id": user["id"],
            "month": month_date.isoformat(),
        }
    )

    month_str = str(created["month"])[:7]
    return BudgetMonthResponse(
        id=created["id"],
        budget_id=created["budget_id"],
        user_id=created["user_id"],
        month=month_str,
        created_at=created["created_at"],
    )


@router.delete("/months/{month_id}", response_model=SuccessResponse)
async def delete_budget_month(
    month_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Remove a budget month override (falls back to default budget)."""
    month = db.get_budget_month_by_id(month_id)
    if not month:
        raise HTTPException(status_code=404, detail="Budget month not found")
    if month["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    db.delete_budget_month(month_id)
    return SuccessResponse(message="Budget month removed (reverted to default budget)")


# ============================================================================
# Budget CRUD
# ============================================================================


@router.get("", response_model=BudgetListResponse)
async def list_budgets(
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """List all budgets for the user."""
    budgets = db.get_budgets(user["id"])
    return BudgetListResponse(
        items=[BudgetResponse(**b) for b in budgets],
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
        "user_id": user["id"],
        "name": budget.name,
        "is_default": budget.is_default,
        "emoji": budget.emoji,
        "color": budget.color,
    }
    created = db.create_budget(budget_data)

    # Associate accounts
    for account_id in budget.account_ids:
        try:
            db.add_budget_account(created["id"], account_id)
        except Exception:
            # Account might already be in another budget
            pass

    return BudgetResponse(**created)


@router.get("/{budget_id}", response_model=BudgetResponse)
async def get_budget(
    budget_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Get a budget by ID."""
    budget = db.get_budget(budget_id)
    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found")
    if budget["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    return BudgetResponse(**budget)


@router.patch("/{budget_id}", response_model=BudgetResponse)
async def update_budget(
    budget_id: str,
    budget: BudgetUpdate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Update a budget's name or default status."""
    existing = db.get_budget(budget_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Budget not found")
    if existing["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    update_data = budget.model_dump(exclude_unset=True)
    updated = db.update_budget(budget_id, update_data)
    if not updated:
        raise HTTPException(status_code=500, detail="Failed to update budget")
    return BudgetResponse(**updated)


@router.delete("/{budget_id}", response_model=SuccessResponse)
async def delete_budget(
    budget_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Delete a budget (cascades to line items, accounts, months)."""
    existing = db.get_budget(budget_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Budget not found")
    if existing["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    db.delete_budget(budget_id)
    return SuccessResponse(message="Budget deleted successfully")


@router.post("/{budget_id}/set-default", response_model=BudgetResponse)
async def set_default_budget(
    budget_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Set a budget as the default."""
    existing = db.get_budget(budget_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Budget not found")
    if existing["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    updated = db.update_budget(budget_id, {"is_default": True})
    return BudgetResponse(**updated)


# ============================================================================
# Budget Accounts
# ============================================================================


@router.get("/{budget_id}/accounts", response_model=BudgetAccountListResponse)
async def list_budget_accounts(
    budget_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """List accounts linked to a budget."""
    budget = db.get_budget(budget_id)
    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found")
    if budget["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    accounts = db.get_budget_accounts(budget_id)
    return BudgetAccountListResponse(
        items=[BudgetAccountResponse(**a) for a in accounts],
        total=len(accounts),
    )


@router.post(
    "/{budget_id}/accounts", response_model=BudgetAccountResponse, status_code=201
)
async def add_budget_account(
    budget_id: str,
    request: BudgetAccountAdd,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Add an account to a budget.

    Returns 409 if account is already linked to another budget.
    """
    budget = db.get_budget(budget_id)
    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found")
    if budget["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Check if account already belongs to another budget
    existing = db.get_account_budget(request.account_id)
    if existing and existing["budget_id"] != budget_id:
        raise HTTPException(
            status_code=409,
            detail=f"Account is already linked to budget '{existing.get('budgets', {}).get('name', 'another budget')}'",
        )

    try:
        db.add_budget_account(budget_id, request.account_id)
        accounts = db.get_budget_accounts(budget_id)
        account = next(
            (a for a in accounts if a["account_id"] == request.account_id), None
        )
        if not account:
            raise HTTPException(
                status_code=500, detail="Failed to fetch account details"
            )
        return BudgetAccountResponse(**account)
    except Exception as e:
        if "unique" in str(e).lower() or "duplicate" in str(e).lower():
            raise HTTPException(
                status_code=409, detail="Account is already linked to this budget"
            )
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/{budget_id}/accounts/{account_id}", response_model=SuccessResponse)
async def remove_budget_account(
    budget_id: str,
    account_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Remove an account from a budget."""
    budget = db.get_budget(budget_id)
    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found")
    if budget["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    db.remove_budget_account(budget_id, account_id)
    return SuccessResponse(message="Account removed from budget")


# ============================================================================
# Budget Line Items
# ============================================================================


@router.get("/{budget_id}/line-items", response_model=BudgetLineItemListResponse)
async def list_line_items(
    budget_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """List all line items for a budget."""
    budget = db.get_budget(budget_id)
    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found")
    if budget["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    items = db.get_budget_line_items(budget_id)
    return BudgetLineItemListResponse(
        items=[BudgetLineItemResponse(**item) for item in items],
        total=len(items),
    )


@router.post(
    "/{budget_id}/line-items", response_model=BudgetLineItemResponse, status_code=201
)
async def create_line_item(
    budget_id: str,
    item: BudgetLineItemCreate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Add a line item to a budget."""
    budget = db.get_budget(budget_id)
    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found")
    if budget["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    try:
        created = db.create_budget_line_item(
            {
                "budget_id": budget_id,
                "category_id": item.category_id,
                "subcategory_id": item.subcategory_id,
                "amount": item.amount,
            }
        )
        return BudgetLineItemResponse(**created)
    except Exception as e:
        if "unique" in str(e).lower() or "duplicate" in str(e).lower():
            raise HTTPException(
                status_code=409,
                detail="A line item for this category already exists in this budget",
            )
        raise HTTPException(status_code=500, detail=str(e))


@router.patch(
    "/{budget_id}/line-items/{item_id}", response_model=BudgetLineItemResponse
)
async def update_line_item(
    budget_id: str,
    item_id: str,
    item: BudgetLineItemUpdate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Update a budget line item amount."""
    budget = db.get_budget(budget_id)
    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found")
    if budget["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    existing_item = db.get_budget_line_item(item_id)
    if not existing_item or existing_item["budget_id"] != budget_id:
        raise HTTPException(status_code=404, detail="Line item not found")

    updated = db.update_budget_line_item(item_id, {"amount": item.amount})
    if not updated:
        raise HTTPException(status_code=500, detail="Failed to update line item")
    return BudgetLineItemResponse(**updated)


@router.delete("/{budget_id}/line-items/{item_id}", response_model=SuccessResponse)
async def delete_line_item(
    budget_id: str,
    item_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Remove a line item from a budget."""
    budget = db.get_budget(budget_id)
    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found")
    if budget["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    existing_item = db.get_budget_line_item(item_id)
    if not existing_item or existing_item["budget_id"] != budget_id:
        raise HTTPException(status_code=404, detail="Line item not found")

    db.delete_budget_line_item(item_id)
    return SuccessResponse(message="Line item removed from budget")
