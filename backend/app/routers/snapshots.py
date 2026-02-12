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
    balance: float = Field(..., description="Balance at end of day")


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
    Get net worth snapshots with flexible granularity.

    Stores daily snapshots but can return weekly/monthly/yearly aggregated views.

    **Examples:**
    - Last 7 days (daily): `/snapshots?granularity=day`
    - Last 4 weeks (weekly): `/snapshots?granularity=week`
    - Last 12 months (monthly): `/snapshots?granularity=month`
    - All time (yearly): `/snapshots?granularity=year`

    **Granularity:**
    - `day`: Daily snapshots (default)
    - `week`: Weekly aggregation (last balance of each week)
    - `month`: Monthly aggregation (last balance of each month)
    - `year`: Yearly aggregation (last balance of each year)

    **Response:**
    - `date`: Date in YYYY-MM-DD format (period start for week/month/year)
    - `balance`: Total net worth at end of period
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
    Get balance snapshots for a specific account with flexible granularity.

    **Examples:**
    - Last 7 days (daily): `/snapshots/account/{account_id}?granularity=day`
    - Last 4 weeks (weekly): `/snapshots/account/{account_id}?granularity=week`
    - Last 12 months (monthly): `/snapshots/account/{account_id}?granularity=month`

    **Response:**
    - `date`: Date in YYYY-MM-DD format
    - `balance`: Account balance at end of period
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
