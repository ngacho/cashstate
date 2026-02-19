"""Goals router — savings and debt payoff goal tracking."""

from datetime import date
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, field_validator

from app.database import Database
from app.dependencies import get_current_user, get_database
from app.logging_config import get_logger
from app.schemas.common import SuccessResponse

router = APIRouter(prefix="/goals", tags=["Goals"])
logger = get_logger("goals")


# ============================================================================
# Pydantic Schemas
# ============================================================================


class GoalAccountCreate(BaseModel):
    simplefin_account_id: str
    # Only meaningful for savings goals; ignored for debt_payment (always 100%)
    allocation_percentage: float = 100.0

    @field_validator("allocation_percentage")
    @classmethod
    def validate_percentage(cls, v: float) -> float:
        if v <= 0 or v > 100:
            raise ValueError("allocation_percentage must be between 0 and 100")
        return v


class GoalCreate(BaseModel):
    name: str
    description: str | None = None
    goal_type: Literal["savings", "debt_payment"] = "savings"
    target_amount: float
    target_date: date | None = None
    accounts: list[GoalAccountCreate]

    @field_validator("target_amount")
    @classmethod
    def validate_target(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("target_amount must be positive")
        return v

    @field_validator("accounts")
    @classmethod
    def validate_accounts(cls, v: list[GoalAccountCreate]) -> list[GoalAccountCreate]:
        if not v:
            raise ValueError("At least one account is required")
        return v


class GoalUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    target_amount: float | None = None
    target_date: date | None = None
    is_completed: bool | None = None
    accounts: list[GoalAccountCreate] | None = None

    @field_validator("target_amount")
    @classmethod
    def validate_target(cls, v: float | None) -> float | None:
        if v is not None and v <= 0:
            raise ValueError("target_amount must be positive")
        return v


class GoalAccountResponse(BaseModel):
    id: str
    simplefin_account_id: str
    account_name: str
    allocation_percentage: float
    current_balance: float
    starting_balance: float | None = None


class GoalResponse(BaseModel):
    id: str
    name: str
    description: str | None
    goal_type: str
    target_amount: float
    target_date: str | None
    is_completed: bool
    current_amount: float
    progress_percent: float
    accounts: list[GoalAccountResponse]
    created_at: str
    updated_at: str


class GoalDetailResponse(GoalResponse):
    progress_data: list[dict]


class GoalListResponse(BaseModel):
    items: list[GoalResponse]
    total: int


# ============================================================================
# Helpers
# ============================================================================


def _compute_progress(
    goal: dict,
    goal_accounts: list[dict],
) -> tuple[float, float]:
    """Return (current_amount, progress_percent) for a goal.

    Savings:      current_amount = sum(balance × allocation%)
                  progress       = current / target × 100

    Debt payoff:  current_amount = sum(abs(starting_balance) - abs(current_balance))
                  = amount of debt actually paid off since goal creation (starts at 0).
                  progress       = current_amount / target × 100
    """
    target = float(goal["target_amount"])

    if goal["goal_type"] == "savings":
        current_amount = sum(
            ga["current_balance"] * (ga["allocation_percentage"] / 100.0)
            for ga in goal_accounts
        )
    else:
        # debt_payment: measure reduction in debt since creation.
        # starting_balance is negative (e.g. -22432), current_balance is negative.
        # As debt is paid off current_balance becomes less negative → difference grows.
        current_amount = sum(
            abs(ga.get("starting_balance") or ga["current_balance"])
            - abs(ga["current_balance"])
            for ga in goal_accounts
        )

    if target <= 0:
        return round(current_amount, 2), 0.0

    progress_percent = max(0.0, min((current_amount / target) * 100.0, 100.0))
    return round(current_amount, 2), round(progress_percent, 2)


def _format_goal_response(goal: dict, goal_accounts: list[dict]) -> GoalResponse:
    current_amount, progress_percent = _compute_progress(goal, goal_accounts)
    return GoalResponse(
        id=goal["id"],
        name=goal["name"],
        description=goal.get("description"),
        goal_type=goal["goal_type"],
        target_amount=float(goal["target_amount"]),
        target_date=goal["target_date"] if goal.get("target_date") else None,
        is_completed=goal["is_completed"],
        current_amount=current_amount,
        progress_percent=progress_percent,
        accounts=[GoalAccountResponse(**ga) for ga in goal_accounts],
        created_at=_format_ts(goal["created_at"]),
        updated_at=_format_ts(goal["updated_at"]),
    )


def _format_ts(ts: str) -> str:
    """Normalize timestamp to ISO string."""
    return ts if isinstance(ts, str) else str(ts)


def _validate_and_create_accounts(
    goal_id: str,
    user_id: str,
    goal_type: str,
    accounts: list[GoalAccountCreate],
    db: Database,
    exclude_goal_id: str | None = None,
) -> None:
    """Validate account balances, allocation limits, then insert goal_accounts."""
    for acc in accounts:
        # Fetch account to check balance and ownership
        account_result = (
            db.client.table("simplefin_accounts")
            .select("id, balance, user_id")
            .eq("id", acc.simplefin_account_id)
            .execute()
        )
        if not account_result.data:
            raise HTTPException(
                status_code=404, detail=f"Account {acc.simplefin_account_id} not found"
            )

        account = account_result.data[0]
        if account["user_id"] != user_id:
            raise HTTPException(
                status_code=403, detail="Not authorized to use this account"
            )

        balance = float(account["balance"] or 0)

        # Goal type / balance polarity checks
        if goal_type == "savings" and balance < 0:
            raise HTTPException(
                status_code=422,
                detail=f"Account has a negative balance ({balance:.2f}). Only positive-balance accounts can be used for savings goals.",
            )
        if goal_type == "debt_payment" and balance > 0:
            raise HTTPException(
                status_code=422,
                detail=f"Account has a positive balance ({balance:.2f}). Only negative-balance accounts can be used for debt payoff goals.",
            )

        if goal_type == "savings":
            # Allocation cap check — only meaningful for savings goals
            existing_alloc = db.get_account_total_allocation(
                acc.simplefin_account_id, exclude_goal_id=exclude_goal_id
            )
            if existing_alloc + acc.allocation_percentage > 100:
                available = 100 - existing_alloc
                raise HTTPException(
                    status_code=422,
                    detail=f"Account is already {existing_alloc:.0f}% allocated across other goals. Only {available:.0f}% remaining.",
                )
            row: dict = {
                "goal_id": goal_id,
                "user_id": user_id,
                "simplefin_account_id": acc.simplefin_account_id,
                "allocation_percentage": acc.allocation_percentage,
            }
        else:
            # debt_payment: always 100%, record starting balance for progress tracking
            row = {
                "goal_id": goal_id,
                "user_id": user_id,
                "simplefin_account_id": acc.simplefin_account_id,
                "allocation_percentage": 100,
                "starting_balance": balance,
            }

        db.create_goal_account(row)


# ============================================================================
# Endpoints
# ============================================================================


@router.post("", response_model=GoalResponse, status_code=201)
async def create_goal(
    payload: GoalCreate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Create a new financial goal with linked accounts."""
    logger.info(f"[POST /goals] User: {user['id']}, goal: {payload.name}")

    # Create goal record
    goal_data = {
        "user_id": user["id"],
        "name": payload.name,
        "description": payload.description,
        "goal_type": payload.goal_type,
        "target_amount": payload.target_amount,
        "target_date": payload.target_date.isoformat() if payload.target_date else None,
    }
    goal = db.create_goal(goal_data)

    # Validate and create account associations
    try:
        _validate_and_create_accounts(
            goal_id=goal["id"],
            user_id=user["id"],
            goal_type=payload.goal_type,
            accounts=payload.accounts,
            db=db,
        )
    except HTTPException:
        # Roll back the goal if account validation fails
        db.delete_goal(goal["id"])
        raise

    goal_accounts = db.get_goal_accounts(goal["id"])
    return _format_goal_response(goal, goal_accounts)


@router.get("", response_model=GoalListResponse)
async def list_goals(
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """List all goals for the user with current progress."""
    logger.info(f"[GET /goals] User: {user['id']}")

    goals = db.get_user_goals(user["id"])
    items = []
    for goal in goals:
        goal_accounts = db.get_goal_accounts(goal["id"])
        items.append(_format_goal_response(goal, goal_accounts))

    return GoalListResponse(items=items, total=len(items))


@router.get("/{goal_id}", response_model=GoalDetailResponse)
async def get_goal(
    goal_id: str,
    start_date: date | None = Query(None, description="Start date YYYY-MM-DD"),
    end_date: date | None = Query(None, description="End date YYYY-MM-DD"),
    granularity: str = Query("day", pattern="^(day|week|month|year)$"),
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Get goal detail with progress chart data."""
    logger.info(f"[GET /goals/{goal_id}] User: {user['id']}")

    goal = db.get_goal(goal_id)
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")
    if goal["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    goal_accounts = db.get_goal_accounts(goal_id)

    # Default date range: 1 month ago → today
    today = date.today()
    if end_date is None:
        end_date = today
    if start_date is None:
        start_date = date(
            today.year - 1 if today.month == 1 else today.year,
            12 if today.month == 1 else today.month - 1,
            today.day,
        )

    snapshots = db.get_goal_snapshots(
        goal_id=goal_id,
        start_date=start_date.isoformat(),
        end_date=end_date.isoformat(),
        granularity=granularity,
        goal_type=goal["goal_type"],
    )

    current_amount, progress_percent = _compute_progress(goal, goal_accounts)

    return GoalDetailResponse(
        id=goal["id"],
        name=goal["name"],
        description=goal.get("description"),
        goal_type=goal["goal_type"],
        target_amount=float(goal["target_amount"]),
        target_date=goal["target_date"] if goal.get("target_date") else None,
        is_completed=goal["is_completed"],
        current_amount=current_amount,
        progress_percent=progress_percent,
        accounts=[GoalAccountResponse(**ga) for ga in goal_accounts],
        created_at=_format_ts(goal["created_at"]),
        updated_at=_format_ts(goal["updated_at"]),
        progress_data=snapshots,
    )


@router.put("/{goal_id}", response_model=GoalResponse)
async def update_goal(
    goal_id: str,
    payload: GoalUpdate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Update a goal's metadata and optionally replace its account allocations."""
    logger.info(f"[PUT /goals/{goal_id}] User: {user['id']}")

    goal = db.get_goal(goal_id)
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")
    if goal["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Build update dict for scalar fields
    update_data: dict = {}
    if payload.name is not None:
        update_data["name"] = payload.name
    if payload.description is not None:
        update_data["description"] = payload.description
    if payload.target_amount is not None:
        update_data["target_amount"] = payload.target_amount
    if payload.target_date is not None:
        update_data["target_date"] = payload.target_date.isoformat()
    if payload.is_completed is not None:
        update_data["is_completed"] = payload.is_completed

    if update_data:
        goal = db.update_goal(goal_id, update_data) or goal

    # Replace account associations if provided
    if payload.accounts is not None:
        db.delete_goal_accounts_for_goal(goal_id)
        _validate_and_create_accounts(
            goal_id=goal_id,
            user_id=user["id"],
            goal_type=goal["goal_type"],
            accounts=payload.accounts,
            db=db,
            exclude_goal_id=goal_id,
        )

    goal_accounts = db.get_goal_accounts(goal_id)
    return _format_goal_response(goal, goal_accounts)


@router.delete("/{goal_id}", response_model=SuccessResponse)
async def delete_goal(
    goal_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Delete a goal and all its account associations."""
    logger.info(f"[DELETE /goals/{goal_id}] User: {user['id']}")

    goal = db.get_goal(goal_id)
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")
    if goal["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    db.delete_goal(goal_id)
    return SuccessResponse(message="Goal deleted successfully")
