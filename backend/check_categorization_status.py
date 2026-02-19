#!/usr/bin/env python3
"""Quick script to check transaction categorization status."""

from app.database import Database
from datetime import datetime


def main():
    db = Database()

    # Get all transactions
    result = (
        db.client.table("simplefin_transactions")
        .select("id, description, amount, category_id, subcategory_id, posted_date")
        .order("posted_date", desc=True)
        .limit(50)
        .execute()
    )

    transactions = result.data

    categorized = [t for t in transactions if t.get("category_id")]
    uncategorized = [t for t in transactions if not t.get("category_id")]

    print("\n" + "=" * 80)
    print("TRANSACTION CATEGORIZATION STATUS")
    print("=" * 80)
    print(f"Total transactions (last 50): {len(transactions)}")
    print(f"Categorized: {len(categorized)}")
    print(f"Uncategorized: {len(uncategorized)}")
    print("=" * 80)

    if categorized:
        print("\n✅ CATEGORIZED TRANSACTIONS:")
        for t in categorized[:10]:  # Show first 10
            date = datetime.fromtimestamp(t["posted_date"]).strftime("%Y-%m-%d")
            print(
                f"  {date} | ${t['amount']:>8.2f} | {t['description'][:40]:<40} | Cat: {t['category_id'][:8]}..."
            )

    if uncategorized:
        print("\n❌ UNCATEGORIZED TRANSACTIONS:")
        for t in uncategorized[:10]:  # Show first 10
            date = datetime.fromtimestamp(t["posted_date"]).strftime("%Y-%m-%d")
            print(f"  {date} | ${t['amount']:>8.2f} | {t['description'][:40]:<40}")

    print("\n" + "=" * 80)


if __name__ == "__main__":
    main()
