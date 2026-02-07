"""Sync job schemas."""

from datetime import datetime
from pydantic import BaseModel


class SyncTriggerResponse(BaseModel):
    """Response after triggering a sync."""

    job_ids: list[str]
    message: str


class SyncJobResponse(BaseModel):
    """Single sync job status."""

    id: str
    plaid_item_id: str
    status: str
    started_at: datetime | None
    completed_at: datetime | None
    error_message: str | None
    transactions_added: int
    transactions_modified: int
    transactions_removed: int
    created_at: datetime


class SyncStatusResponse(BaseModel):
    """List of sync jobs."""

    jobs: list[SyncJobResponse]
