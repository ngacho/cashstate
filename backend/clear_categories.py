#!/usr/bin/env python3
"""Script to clear all transaction categorizations."""

from app.database import Database
from app.config import get_settings

def main():
    print("Clearing all transaction categorizations...")

    settings = get_settings()
    db = Database()

    # Clear all categorizations
    result = db.client.table("simplefin_transactions").update({
        "category_id": None,
        "subcategory_id": None
    }).neq("category_id", None).execute()

    count = len(result.data) if result.data else 0
    print(f"✓ Cleared {count} transactions")

    # Show total uncategorized count
    total = db.client.table("simplefin_transactions").select("id", count="exact").is_("category_id", None).execute()
    print(f"Total uncategorized transactions: {total.count}")

if __name__ == "__main__":
    main()
