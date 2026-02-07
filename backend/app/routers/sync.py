"""Sync router - trigger and monitor transaction syncs."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.database import Database
from app.dependencies import get_current_user, get_database
from app.schemas.sync import SyncTriggerResponse, SyncJobResponse, SyncStatusResponse
from app.services import sync_service


router = APIRouter(prefix="/sync", tags=["Sync"])


@router.post("/trigger", response_model=SyncTriggerResponse)
async def trigger_sync_all(
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Trigger a sync for all of the current user's active Plaid items."""
    items = db.get_user_active_plaid_items(user["id"])
    if not items:
        return SyncTriggerResponse(job_ids=[], message="No active Plaid items to sync")

    job_ids = []
    for item in items:
        try:
            job = sync_service.sync_item(db, item["id"])
            job_ids.append(job["id"])
        except Exception:
            pass

    return SyncTriggerResponse(
        job_ids=job_ids,
        message=f"Synced {len(job_ids)} of {len(items)} items",
    )


@router.post("/trigger/{item_id}", response_model=SyncTriggerResponse)
async def trigger_sync_item(
    item_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Trigger a sync for a specific Plaid item."""
    item = db.get_plaid_item_by_id(item_id)
    if item is None or item["user_id"] != user["id"]:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Plaid item not found",
        )

    job = sync_service.sync_item(db, item_id)
    return SyncTriggerResponse(
        job_ids=[job["id"]],
        message="Sync completed",
    )


@router.get("/status", response_model=SyncStatusResponse)
async def get_sync_status(
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Get all sync jobs for the current user."""
    jobs = db.get_sync_jobs_for_user(user["id"])
    return SyncStatusResponse(
        jobs=[
            SyncJobResponse(
                id=job["id"],
                plaid_item_id=job["plaid_item_id"],
                status=job["status"],
                started_at=job.get("started_at"),
                completed_at=job.get("completed_at"),
                error_message=job.get("error_message"),
                transactions_added=job.get("transactions_added", 0),
                transactions_modified=job.get("transactions_modified", 0),
                transactions_removed=job.get("transactions_removed", 0),
                created_at=job["created_at"],
            )
            for job in jobs
        ]
    )


@router.get("/status/{job_id}", response_model=SyncJobResponse)
async def get_sync_job(
    job_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Get a specific sync job."""
    job = db.get_sync_job_by_id(job_id)
    if job is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sync job not found",
        )

    # Verify ownership via the plaid_item
    item = db.get_plaid_item_by_id(job["plaid_item_id"])
    if item is None or item["user_id"] != user["id"]:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sync job not found",
        )

    return SyncJobResponse(
        id=job["id"],
        plaid_item_id=job["plaid_item_id"],
        status=job["status"],
        started_at=job.get("started_at"),
        completed_at=job.get("completed_at"),
        error_message=job.get("error_message"),
        transactions_added=job.get("transactions_added", 0),
        transactions_modified=job.get("transactions_modified", 0),
        transactions_removed=job.get("transactions_removed", 0),
        created_at=job["created_at"],
    )
