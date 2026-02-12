"""API routers."""

from app.routers.auth import router as auth_router
from app.routers.plaid import router as plaid_router
from app.routers.simplefin import router as simplefin_router
from app.routers.sync import router as sync_router
from app.routers.transactions import router as transactions_router

__all__ = [
    "auth_router",
    "plaid_router",
    "simplefin_router",
    "sync_router",
    "transactions_router",
]
