"""Budget summary computation service."""

from datetime import date
from app.database import Database


class BudgetService:
    """Service for computing budget summaries."""

    def __init__(self, db: Database):
        self.db = db

    def get_budget_summary(self, user_id: str, month_str: str) -> dict | None:
        """Compute budget summary for a given month.

        Logic:
        1. Parse month "YYYY-MM" → date YYYY-MM-01
        2. Check budget_months for explicit budget override
        3. If not found → use is_default=True budget
        4. If no default → return None (404)
        5. Get line items, linked accounts, and compute actuals
        6. Find categories with spending but NO line item → unbudgeted
        7. Return structured BudgetSummary

        Args:
            user_id: User's UUID
            month_str: Month in "YYYY-MM" format

        Returns:
            dict matching BudgetSummary schema, or None if no budget found
        """
        # Parse month
        try:
            year, month = month_str.split("-")
            month_date = date(int(year), int(month), 1)
        except (ValueError, AttributeError):
            raise ValueError(f"Invalid month format: {month_str}. Expected YYYY-MM")

        month_db_str = month_date.isoformat()  # "YYYY-MM-01"

        # Find the active budget for this month
        month_override = self.db.get_budget_month(user_id, month_db_str)
        if month_override:
            budget_id = month_override["budget_id"]
        else:
            default_budget = self.db.get_default_budget(user_id)
            if not default_budget:
                return None
            budget_id = default_budget["id"]

        budget = self.db.get_budget(budget_id)
        if not budget:
            return None

        # Verify ownership
        if budget["user_id"] != user_id:
            return None

        # Get line items and linked accounts
        line_items = self.db.get_budget_line_items(budget_id)
        account_ids = self.db.get_budget_account_ids(budget_id)

        # Compute month date range
        if month_date.month == 12:
            end_date = date(month_date.year + 1, 1, 1)
        else:
            end_date = date(month_date.year, month_date.month + 1, 1)

        # Get actual spending for the month
        spending = self.db.get_spending_by_category(
            user_id=user_id,
            start_date=month_date,
            end_date=end_date,
            account_ids=account_ids if account_ids else None,
        )

        category_spending = spending["categories"]
        subcategory_spending = spending["subcategories"]
        uncategorized_spending = spending["uncategorized"]

        # Build line items with actuals
        summary_line_items = []
        budgeted_category_ids = set()

        for item in line_items:
            if item.get("subcategory_id"):
                # Subcategory-level line item — use subcategory spending directly
                spent = subcategory_spending.get(item["subcategory_id"], 0.0)
            else:
                spent = category_spending.get(item["category_id"], 0.0)
                budgeted_category_ids.add(item["category_id"])

            amount = float(item["amount"])
            summary_line_items.append(
                {
                    "id": item["id"],
                    "budget_id": budget_id,
                    "category_id": item["category_id"],
                    "subcategory_id": item.get("subcategory_id"),
                    "amount": amount,
                    "spent": round(spent, 2),
                    "remaining": round(amount - spent, 2),
                }
            )

        # Find unbudgeted categories (have spending but no line item)
        unbudgeted_categories = []
        for cat_id, spent_amount in category_spending.items():
            if cat_id not in budgeted_category_ids and spent_amount > 0:
                unbudgeted_categories.append(
                    {
                        "category_id": cat_id,
                        "spent": round(spent_amount, 2),
                    }
                )

        total_budgeted = sum(item["amount"] for item in summary_line_items)
        total_spent = sum(item["spent"] for item in summary_line_items)
        total_spent += sum(uc["spent"] for uc in unbudgeted_categories)
        total_spent += uncategorized_spending

        return {
            "budget_id": budget_id,
            "budget_name": budget["name"],
            "month": month_str,
            "total_budgeted": round(total_budgeted, 2),
            "total_spent": round(total_spent, 2),
            "line_items": summary_line_items,
            "unbudgeted_categories": unbudgeted_categories,
            "subcategory_spending": {
                k: round(v, 2) for k, v in subcategory_spending.items()
            },
            "uncategorized_spending": round(uncategorized_spending, 2),
        }


def get_budget_service(db: Database) -> BudgetService:
    """Get budget service instance."""
    return BudgetService(db=db)
