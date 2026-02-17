"""API routers."""

from app.routers.auth import router as auth_router
from app.routers.budget_templates import router as budget_templates_router
from app.routers.categories import router as categories_router
from app.routers.plaid import router as plaid_router
from app.routers.simplefin import router as simplefin_router
from app.routers.snapshots import router as snapshots_router
from app.routers.sync import router as sync_router
from app.routers.transactions import router as transactions_router

__all__ = [
    "auth_router",
    "budget_templates_router",
    "categories_router",
    "plaid_router",
    "simplefin_router",
    "snapshots_router",
    "sync_router",
    "transactions_router",
]
