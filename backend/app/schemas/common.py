"""Common schemas used across the application."""

from datetime import datetime
from typing import Any, Generic, TypeVar
from pydantic import BaseModel, Field


T = TypeVar("T")


class SuccessResponse(BaseModel):
    """Generic success response."""

    success: bool = True
    message: str = "Operation completed successfully"
    data: dict[str, Any] | None = None


class ErrorResponse(BaseModel):
    """Generic error response."""

    success: bool = False
    error: str
    detail: str | None = None


class PaginatedResponse(BaseModel, Generic[T]):
    """Paginated response wrapper."""

    items: list[T]
    total: int
    page: int
    page_size: int
    has_more: bool


class LocationInput(BaseModel):
    """Location coordinates input."""

    latitude: float = Field(..., ge=-90, le=90, description="Latitude coordinate")
    longitude: float = Field(..., ge=-180, le=180, description="Longitude coordinate")
    accuracy: float | None = Field(None, ge=0, description="Location accuracy in meters")
    timestamp: datetime | None = Field(None, description="When location was recorded")


class GeoPoint(BaseModel):
    """Geographic point representation."""

    latitude: float
    longitude: float


class TimeRange(BaseModel):
    """Time range for filtering."""

    start: datetime
    end: datetime | None = None
