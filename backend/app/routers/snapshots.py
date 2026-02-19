"""Router for financial snapshots (account balance history and net worth)."""

from datetime import date
from typing import Optional, List
from fastapi import APIRouter, Depends, Query, HTTPException
from pydantic import BaseModel, Field
from app.dependencies import get_current_user_with_token, get_database
from app.services.snapshot_service import SnapshotService, InsufficientDataError

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


class InsufficientDataResponse(BaseModel):
    """Response when insufficient data is available."""

    error: str = "INSUFFICIENT_DATA"
    message: str
    coverage_pct: float
    min_date: Optional[str] = None
    max_date: Optional[str] = None


@router.get("", response_model=SnapshotsResponse)
async def get_snapshots(
    start_date: Optional[date] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(
        None, description="End date (YYYY-MM-DD, defaults to today)"
    ),
    granularity: str = Query(
        "day", pattern="^(day|week|month|year)$", description="Aggregation level"
    ),
    user_and_token=Depends(get_current_user_with_token),
    db=Depends(get_database),
):
    """
    Get net worth snapshots by summing all account balances.

    Calculates net worth on-the-fly from account_balance_history.

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
    - `date`: Date in YYYY-MM-DD format
    - `balance`: Total net worth (sum of all accounts) at end of period

    **Error (422):**
    Returns `INSUFFICIENT_DATA` error if less than 50% of requested dates have data.
    """
    user, _ = user_and_token
    snapshot_service = SnapshotService(db)

    try:
        # Get snapshots (net worth calculated from account balances)
        snapshots = await snapshot_service.get_snapshots(
            user_id=user["id"],
            start_date=start_date,
            end_date=end_date,
            granularity=granularity,
        )

        # Determine actual date range from data
        actual_start = (
            start_date.isoformat()
            if start_date
            else (snapshots[0]["date"] if snapshots else date.today().isoformat())
        )
        actual_end = end_date.isoformat() if end_date else date.today().isoformat()

        return SnapshotsResponse(
            start_date=actual_start,
            end_date=actual_end,
            granularity=granularity,
            data=[SnapshotData(**s) for s in snapshots],
        )
    except InsufficientDataError as e:
        raise HTTPException(
            status_code=422,
            detail={
                "error": "INSUFFICIENT_DATA",
                "message": e.message,
                "coverage_pct": e.coverage_pct,
                "min_date": e.min_date.isoformat() if e.min_date else None,
                "max_date": e.max_date.isoformat() if e.max_date else None,
            },
        )


@router.get("/account/{account_id}", response_model=SnapshotsResponse)
async def get_account_snapshots(
    account_id: str,
    start_date: Optional[date] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(
        None, description="End date (YYYY-MM-DD, defaults to today)"
    ),
    granularity: str = Query(
        "day", pattern="^(day|week|month|year)$", description="Aggregation level"
    ),
    user_and_token=Depends(get_current_user_with_token),
    db=Depends(get_database),
):
    """
    Get balance snapshots for a specific account.

    **Examples:**
    - Last 7 days (daily): `/snapshots/account/{account_id}?granularity=day`
    - Last 4 weeks (weekly): `/snapshots/account/{account_id}?granularity=week`
    - Last 12 months (monthly): `/snapshots/account/{account_id}?granularity=month`

    **Response:**
    - `date`: Date in YYYY-MM-DD format
    - `balance`: Account balance at end of period

    **Error (422):**
    Returns `INSUFFICIENT_DATA` error if less than 50% of requested dates have data.
    """
    user, _ = user_and_token
    snapshot_service = SnapshotService(db)

    try:
        # Get snapshots for this specific account
        snapshots = await snapshot_service.get_account_snapshots(
            user_id=user["id"],
            account_id=account_id,
            start_date=start_date,
            end_date=end_date,
            granularity=granularity,
        )

        # Determine actual date range
        actual_start = (
            start_date.isoformat()
            if start_date
            else (snapshots[0]["date"] if snapshots else date.today().isoformat())
        )
        actual_end = end_date.isoformat() if end_date else date.today().isoformat()

        return SnapshotsResponse(
            start_date=actual_start,
            end_date=actual_end,
            granularity=granularity,
            data=[SnapshotData(**s) for s in snapshots],
        )
    except InsufficientDataError as e:
        raise HTTPException(
            status_code=422,
            detail={
                "error": "INSUFFICIENT_DATA",
                "message": e.message,
                "coverage_pct": e.coverage_pct,
                "min_date": e.min_date.isoformat() if e.min_date else None,
                "max_date": e.max_date.isoformat() if e.max_date else None,
            },
        )


@router.post("/store")
async def store_daily_snapshots(
    snapshot_date: Optional[date] = Query(
        None, description="Date to snapshot (defaults to today)"
    ),
    user_and_token=Depends(get_current_user_with_token),
    db=Depends(get_database),
):
    """
    Store daily account balance snapshots.

    Called automatically by cron job, but can be triggered manually if needed.
    Snapshots current balances from simplefin_accounts table.
    """
    user, _ = user_and_token
    snapshot_service = SnapshotService(db)

    await snapshot_service.store_daily_account_balances(
        user_id=user["id"], snapshot_date=snapshot_date
    )

    return {
        "success": True,
        "message": f"Account balances snapshotted for {snapshot_date or date.today()}",
    }
