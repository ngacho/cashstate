"""Router for financial snapshots (net worth tracking over time)."""
from datetime import date
from typing import Optional, List
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from app.dependencies import get_current_user_with_token, get_database
from app.services.snapshot_service import SnapshotService

router = APIRouter(prefix="/snapshots", tags=["snapshots"])


class SnapshotData(BaseModel):
    """Single snapshot data point."""
    date: str = Field(..., description="Date in YYYY-MM-DD format")
    balance: float = Field(..., description="Total balance (net worth)")
    spent: float = Field(..., description="Amount spent in this period")
    income: float = Field(..., description="Amount earned in this period")
    net: float = Field(..., description="Net change (income - spent)")
    transaction_count: int = Field(..., description="Number of transactions")


class SnapshotsResponse(BaseModel):
    """Response containing snapshot data."""
    start_date: str
    end_date: str
    granularity: str
    data: List[SnapshotData]


@router.get("", response_model=SnapshotsResponse)
async def get_snapshots(
    start_date: Optional[date] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(None, description="End date (YYYY-MM-DD, defaults to today)"),
    granularity: str = Query("day", pattern="^(day|week|month|year)$", description="Aggregation level"),
    user_and_token=Depends(get_current_user_with_token),
    db=Depends(get_database)
):
    """
    Get financial snapshots with flexible date range and granularity.

    **Examples:**
    - Last 7 days (daily): `?granularity=day`
    - Specific week (daily): `?start_date=2024-01-15&end_date=2024-01-21&granularity=day`
    - Last month (weekly): `?granularity=week`
    - Specific month (weekly): `?start_date=2024-01-01&end_date=2024-01-31&granularity=week`
    - Last year (monthly): `?granularity=month`
    - All time (yearly): `?granularity=year`

    **Granularity options:**
    - `day`: Individual daily snapshots
    - `week`: Aggregated by week (Monday-Sunday)
    - `month`: Aggregated by month
    - `year`: Aggregated by year

    **Response:**
    - `balance`: Total net worth at end of period
    - `spent`: Total amount spent in period
    - `income`: Total income in period
    - `net`: Net change (income - spent)
    """
    user, _ = user_and_token
    snapshot_service = SnapshotService(db)

    # Get snapshots
    snapshots = await snapshot_service.get_snapshots(
        user_id=user["id"],
        start_date=start_date,
        end_date=end_date,
        granularity=granularity
    )

    # Determine actual date range from data
    actual_start = start_date.isoformat() if start_date else (snapshots[0]["date"] if snapshots else date.today().isoformat())
    actual_end = end_date.isoformat() if end_date else date.today().isoformat()

    return SnapshotsResponse(
        start_date=actual_start,
        end_date=actual_end,
        granularity=granularity,
        data=[SnapshotData(**s) for s in snapshots]
    )


@router.post("/calculate")
async def calculate_snapshots(
    start_date: Optional[date] = Query(None, description="Start date (defaults to first transaction)"),
    end_date: Optional[date] = Query(None, description="End date (defaults to today)"),
    user_and_token=Depends(get_current_user_with_token),
    db=Depends(get_database)
):
    """
    Calculate/recalculate daily snapshots for a date range.

    Calculates both:
    - User-level snapshots (net worth)
    - Account-level snapshots (per-account balance history)

    Called automatically after transaction sync, but can be triggered manually
    if needed (e.g., to rebuild history or fix discrepancies).
    """
    user, _ = user_and_token
    snapshot_service = SnapshotService(db)

    # Calculate user-level snapshots (net worth)
    await snapshot_service.calculate_snapshots(
        user_id=user["id"],
        start_date=start_date,
        end_date=end_date
    )

    # Calculate account-level snapshots (per-account balance history)
    await snapshot_service.calculate_transaction_snapshots(
        user_id=user["id"],
        start_date=start_date,
        end_date=end_date
    )

    return {
        "success": True,
        "message": f"Snapshots calculated from {start_date or 'first transaction'} to {end_date or 'today'}"
    }


@router.get("/account/{account_id}", response_model=SnapshotsResponse)
async def get_transaction_snapshots(
    account_id: str,
    start_date: Optional[date] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(None, description="End date (YYYY-MM-DD, defaults to today)"),
    granularity: str = Query("day", pattern="^(day|week|month|year)$", description="Aggregation level"),
    user_and_token=Depends(get_current_user_with_token),
    db=Depends(get_database)
):
    """
    Get balance snapshots for a specific account.

    Returns historical balance data for individual account charts.

    **Examples:**
    - Last 7 days: `/snapshots/account/{account_id}?granularity=day`
    - Specific month: `/snapshots/account/{account_id}?start_date=2024-01-01&end_date=2024-01-31&granularity=week`

    **Response:**
    - `balance`: Account balance at end of period
    - `spent`: Amount spent from this account in period
    - `income`: Amount received into this account in period
    - `net`: Net change (income - spent)
    """
    user, _ = user_and_token
    snapshot_service = SnapshotService(db)

    # Get snapshots for this specific account
    snapshots = await snapshot_service.get_transaction_snapshots(
        user_id=user["id"],
        account_id=account_id,
        start_date=start_date,
        end_date=end_date,
        granularity=granularity
    )

    # Determine actual date range
    actual_start = start_date.isoformat() if start_date else (snapshots[0]["date"] if snapshots else date.today().isoformat())
    actual_end = end_date.isoformat() if end_date else date.today().isoformat()

    return SnapshotsResponse(
        start_date=actual_start,
        end_date=actual_end,
        granularity=granularity,
        data=[SnapshotData(**s) for s in snapshots]
    )
