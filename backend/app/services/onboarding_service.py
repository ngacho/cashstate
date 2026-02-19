"""User onboarding service for seeding default categories and budgets."""

from app.database import Database


# Default category and subcategory data (using cross-platform emojis)
# NOTE: Income and Transfers are intentionally excluded from defaults
# They belong in goals/net worth tracking, not expense budgeting
DEFAULT_CATEGORIES = [
    # Essential Expenses
    {
        "name": "Housing",
        "icon": "🏠",
        "color": "#7C5CFC",  # violet
        "display_order": 10,
        "subcategories": [
            {"name": "Rent", "icon": "🏘️", "display_order": 1},
            {"name": "Mortgage", "icon": "🏢", "display_order": 2},
            {"name": "Property Tax", "icon": "📝", "display_order": 3},
            {"name": "Home Insurance", "icon": "🛡️", "display_order": 4},
            {"name": "HOA Fees", "icon": "👥", "display_order": 5},
            {"name": "Maintenance & Repairs", "icon": "🔧", "display_order": 6},
            {"name": "Furniture & Decor", "icon": "🛋️", "display_order": 7},
        ],
    },
    {
        "name": "Transportation",
        "icon": "🚗",
        "color": "#E8853A",  # burnt orange
        "display_order": 11,
        "subcategories": [
            {"name": "Gas & Fuel", "icon": "⛽", "display_order": 1},
            {"name": "Car Payment", "icon": "🚙", "display_order": 2},
            {"name": "Car Insurance", "icon": "🛡️", "display_order": 3},
            {"name": "Maintenance & Repairs", "icon": "🔧", "display_order": 4},
            {"name": "Public Transit", "icon": "🚌", "display_order": 5},
            {"name": "Ride Share", "icon": "🚕", "display_order": 6},
            {"name": "Parking", "icon": "🅿️", "display_order": 7},
        ],
    },
    {
        "name": "Food & Dining",
        "icon": "🍽️",
        "color": "#E05252",  # warm red
        "display_order": 12,
        "subcategories": [
            {"name": "Groceries", "icon": "🛒", "display_order": 1},
            {"name": "Restaurants", "icon": "🍴", "display_order": 2},
            {"name": "Coffee Shops", "icon": "☕", "display_order": 3},
            {"name": "Fast Food", "icon": "🍔", "display_order": 4},
            {"name": "Delivery", "icon": "📦", "display_order": 5},
        ],
    },
    {
        "name": "Utilities",
        "icon": "⚡",
        "color": "#3A8FE8",  # sky blue
        "display_order": 13,
        "subcategories": [
            {"name": "Electricity", "icon": "💡", "display_order": 1},
            {"name": "Water", "icon": "💧", "display_order": 2},
            {"name": "Gas", "icon": "🔥", "display_order": 3},
            {"name": "Internet", "icon": "📡", "display_order": 4},
            {"name": "Phone", "icon": "📱", "display_order": 5},
            {"name": "Trash & Recycling", "icon": "🗑️", "display_order": 6},
        ],
    },
    {
        "name": "Healthcare",
        "icon": "🏥",
        "color": "#E54D8A",  # magenta pink
        "display_order": 14,
        "subcategories": [
            {"name": "Doctor Visits", "icon": "⚕️", "display_order": 1},
            {"name": "Prescriptions", "icon": "💊", "display_order": 2},
            {"name": "Dental", "icon": "🦷", "display_order": 3},
            {"name": "Vision", "icon": "👁️", "display_order": 4},
            {"name": "Mental Health", "icon": "🧠", "display_order": 5},
            {"name": "Medical Devices", "icon": "🩹", "display_order": 6},
        ],
    },
    {
        "name": "Insurance",
        "icon": "🛡️",
        "color": "#5A6DEA",  # indigo
        "display_order": 15,
        "subcategories": [
            {"name": "Health Insurance", "icon": "🏥", "display_order": 1},
            {"name": "Life Insurance", "icon": "❤️", "display_order": 2},
            {"name": "Disability Insurance", "icon": "🚶", "display_order": 3},
        ],
    },
    # Lifestyle
    {
        "name": "Shopping",
        "icon": "🛍️",
        "color": "#13B5C7",  # teal
        "display_order": 20,
        "subcategories": [
            {"name": "Clothing", "icon": "👕", "display_order": 1},
            {"name": "Shoes", "icon": "👟", "display_order": 2},
            {"name": "Electronics", "icon": "💻", "display_order": 3},
            {"name": "Home Goods", "icon": "🏠", "display_order": 4},
            {"name": "Books", "icon": "📖", "display_order": 5},
            {"name": "Hobbies", "icon": "🎨", "display_order": 6},
            {"name": "General Shopping", "icon": "🛒", "display_order": 7},
        ],
    },
    {
        "name": "Entertainment",
        "icon": "🎮",
        "color": "#A855F7",  # purple
        "display_order": 21,
        "subcategories": [
            {"name": "Movies & Shows", "icon": "🎬", "display_order": 1},
            {"name": "Music & Concerts", "icon": "🎵", "display_order": 2},
            {"name": "Sports & Fitness", "icon": "🏃", "display_order": 3},
            {"name": "Gaming", "icon": "🎮", "display_order": 4},
            {"name": "Events & Activities", "icon": "🎫", "display_order": 5},
            {"name": "Hobbies", "icon": "📷", "display_order": 6},
        ],
    },
    {
        "name": "Personal Care",
        "icon": "✨",
        "color": "#D46EB3",  # orchid
        "display_order": 22,
        "subcategories": [
            {"name": "Hair Care", "icon": "💇", "display_order": 1},
            {"name": "Skincare", "icon": "🧴", "display_order": 2},
            {"name": "Spa & Massage", "icon": "💆", "display_order": 3},
            {"name": "Gym Membership", "icon": "🏋️", "display_order": 4},
            {"name": "Personal Items", "icon": "🧼", "display_order": 5},
        ],
    },
    {
        "name": "Education",
        "icon": "📚",
        "color": "#0FA87E",  # emerald
        "display_order": 23,
        "subcategories": [
            {"name": "Tuition", "icon": "🎓", "display_order": 1},
            {"name": "Books & Supplies", "icon": "📚", "display_order": 2},
            {"name": "Online Courses", "icon": "💻", "display_order": 3},
            {"name": "Student Loans", "icon": "📄", "display_order": 4},
        ],
    },
    {
        "name": "Subscriptions",
        "icon": "🔁",
        "color": "#6C7BDB",  # periwinkle
        "display_order": 24,
        "subcategories": [
            {"name": "Streaming Services", "icon": "📺", "display_order": 1},
            {"name": "Music Streaming", "icon": "🎵", "display_order": 2},
            {"name": "Cloud Storage", "icon": "☁️", "display_order": 3},
            {"name": "Software", "icon": "📱", "display_order": 4},
            {"name": "News & Magazines", "icon": "📰", "display_order": 5},
            {"name": "Other Subscriptions", "icon": "🔁", "display_order": 6},
        ],
    },
    # Financial
    {
        "name": "Savings & Investments",
        "icon": "📈",
        "color": "#22AD6A",  # green
        "display_order": 30,
        "subcategories": [
            {"name": "Emergency Fund", "icon": "🆘", "display_order": 1},
            {"name": "Retirement", "icon": "👴", "display_order": 2},
            {"name": "Investments", "icon": "📈", "display_order": 3},
            {"name": "Savings Goals", "icon": "🎯", "display_order": 4},
        ],
    },
    {
        "name": "Debt Payments",
        "icon": "💳",
        "color": "#CF3E3E",  # crimson
        "display_order": 31,
        "subcategories": [
            {"name": "Credit Card", "icon": "💳", "display_order": 1},
            {"name": "Personal Loan", "icon": "💵", "display_order": 2},
            {"name": "Student Loan", "icon": "🎓", "display_order": 3},
            {"name": "Other Debt", "icon": "📄", "display_order": 4},
        ],
    },
    {
        "name": "Taxes",
        "icon": "📄",
        "color": "#7C8694",  # slate
        "display_order": 32,
        "subcategories": [
            {"name": "Federal Tax", "icon": "🏛️", "display_order": 1},
            {"name": "State Tax", "icon": "📍", "display_order": 2},
            {"name": "Property Tax", "icon": "🏠", "display_order": 3},
        ],
    },
    {
        "name": "Fees & Charges",
        "icon": "⚠️",
        "color": "#D4A03A",  # goldenrod
        "display_order": 33,
        "subcategories": [
            {"name": "Bank Fees", "icon": "🏦", "display_order": 1},
            {"name": "ATM Fees", "icon": "💵", "display_order": 2},
            {"name": "Late Fees", "icon": "⏰", "display_order": 3},
            {"name": "Service Charges", "icon": "🔧", "display_order": 4},
        ],
    },
    # Other
    {
        "name": "Gifts & Donations",
        "icon": "🎁",
        "color": "#E0599E",  # rose
        "display_order": 40,
        "subcategories": [
            {"name": "Gifts", "icon": "🎁", "display_order": 1},
            {"name": "Charity", "icon": "❤️", "display_order": 2},
            {"name": "Religious Donations", "icon": "🙏", "display_order": 3},
        ],
    },
    {
        "name": "Travel",
        "icon": "✈️",
        "color": "#3AAFCC",  # cerulean
        "display_order": 41,
        "subcategories": [
            {"name": "Flights", "icon": "✈️", "display_order": 1},
            {"name": "Hotels", "icon": "🏨", "display_order": 2},
            {"name": "Car Rental", "icon": "🚗", "display_order": 3},
            {"name": "Vacation Activities", "icon": "🎫", "display_order": 4},
        ],
    },
    {
        "name": "Business Expenses",
        "icon": "💼",
        "color": "#4A80D9",  # cobalt
        "display_order": 42,
        "subcategories": [
            {"name": "Office Supplies", "icon": "📎", "display_order": 1},
            {"name": "Business Travel", "icon": "✈️", "display_order": 2},
            {"name": "Client Meetings", "icon": "👥", "display_order": 3},
            {"name": "Professional Services", "icon": "💼", "display_order": 4},
        ],
    },
    {
        "name": "Uncategorized",
        "icon": "❓",
        "color": "#9CA3AF",  # gray
        "display_order": 99,
        "subcategories": [],
    },
]


class OnboardingService:
    """Service for onboarding new users with default categories."""

    def __init__(self, db: Database):
        self.db = db

    def seed_default_categories(
        self, user_id: str, monthly_budget: float = None, account_ids: list[str] = None
    ) -> dict:
        """Seed default categories and subcategories for a new user.

        Creates all default categories with is_default=True, creates a default
        budget, and distributes monthly_budget evenly across expense categories.
        """
        categories_created = 0
        subcategories_created = 0
        budgets_created = 0

        # Filter out non-expense categories for budget allocation
        expense_categories = [
            cat
            for cat in DEFAULT_CATEGORIES
            if cat["name"] not in ["Income", "Transfers", "Uncategorized"]
        ]

        # Calculate budget per expense category if monthly_budget provided
        budget_per_category = None
        if monthly_budget and expense_categories:
            budget_per_category = monthly_budget / len(expense_categories)

        created_categories = []

        for cat_data in DEFAULT_CATEGORIES:
            category = self.db.create_category(
                {
                    "user_id": user_id,
                    "name": cat_data["name"],
                    "icon": cat_data["icon"],
                    "color": cat_data["color"],
                    "is_default": True,  # Seeded from defaults
                    "display_order": cat_data["display_order"],
                }
            )
            categories_created += 1
            created_categories.append(
                {
                    "category": category,
                    "is_expense": cat_data["name"]
                    not in ["Income", "Transfers", "Uncategorized"],
                    "subcategory_count": len(cat_data.get("subcategories", [])),
                }
            )

            for sub_data in cat_data.get("subcategories", []):
                self.db.create_subcategory(
                    {
                        "category_id": category["id"],
                        "user_id": user_id,
                        "name": sub_data["name"],
                        "icon": sub_data["icon"],
                        "is_default": True,  # Seeded from defaults
                        "display_order": sub_data["display_order"],
                    }
                )
                subcategories_created += 1

        # Create budget if monthly_budget was provided
        if monthly_budget and budget_per_category:
            budget = self.db.create_budget(
                {
                    "user_id": user_id,
                    "name": "My Budget",
                    "is_default": True,
                }
            )

            # Associate accounts with budget
            if account_ids:
                for account_id in account_ids:
                    try:
                        self.db.add_budget_account(budget["id"], account_id)
                    except Exception:
                        pass  # Skip if account already linked to another budget

            # Create line items for each expense category
            for cat_info in created_categories:
                if cat_info["is_expense"]:
                    self.db.create_budget_line_item(
                        {
                            "budget_id": budget["id"],
                            "category_id": cat_info["category"]["id"],
                            "subcategory_id": None,
                            "amount": round(budget_per_category, 2),
                        }
                    )
                    budgets_created += 1

        return {
            "categories_created": categories_created,
            "subcategories_created": subcategories_created,
            "budgets_created": budgets_created,
            "monthly_budget": monthly_budget or 0.0,
            "budget_per_category": round(budget_per_category, 2)
            if budget_per_category
            else 0.0,
        }


def get_onboarding_service(db: Database) -> OnboardingService:
    """Get onboarding service instance."""
    return OnboardingService(db=db)
