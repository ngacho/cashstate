"""Categories and subcategories router."""

from fastapi import APIRouter, Depends, HTTPException

from app.database import Database
from app.dependencies import get_current_user, get_database
from app.logging_config import get_logger
from app.schemas.category import (
    CategoryCreate,
    CategoryUpdate,
    CategoryResponse,
    CategoryListResponse,
    CategoryWithSubcategories,
    CategoriesTreeResponse,
    SubcategoryCreate,
    SubcategoryUpdate,
    SubcategoryResponse,
    SubcategoryListResponse,
    CategorizationRequest,
    CategorizationResponse,
    CategorizationRuleCreate,
    CategorizationRuleResponse,
    CategorizationRuleListResponse,
    ManualCategorizationRequest,
    SeedDefaultsRequest,
    SeedDefaultsResponse,
)
from app.schemas.common import SuccessResponse
from app.services.categorization_service import get_categorization_service
from app.services.onboarding_service import get_onboarding_service


router = APIRouter(prefix="/categories", tags=["Categories"])
logger = get_logger("categories")


# ============================================================================
# Onboarding Endpoint
# ============================================================================


@router.post("/seed-defaults", response_model=SeedDefaultsResponse)
async def seed_default_categories(
    request: SeedDefaultsRequest,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Seed default categories, subcategories, and budgets for a new user.

    This endpoint creates a complete set of default categories (Income, Housing,
    Food & Dining, etc.), their subcategories, and allocates the monthly budget
    evenly across expense categories.

    Should be called once during user onboarding.
    """
    onboarding_service = get_onboarding_service(db)
    result = onboarding_service.seed_default_categories(
        user_id=user["id"],
        monthly_budget=request.monthly_budget,
        account_ids=request.account_ids,
    )

    return SeedDefaultsResponse(**result)


# ============================================================================
# Categories Endpoints
# ============================================================================


@router.get("", response_model=CategoryListResponse)
async def list_categories(
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """List all categories (system + user's own)."""
    categories = db.get_categories(user["id"])
    return CategoryListResponse(
        items=[CategoryResponse(**cat) for cat in categories],
        total=len(categories),
    )


@router.get("/tree", response_model=CategoriesTreeResponse)
async def get_categories_tree(
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Get categories with nested subcategories."""
    logger.info(f"[GET /categories/tree] User: {user['id']}")

    categories = db.get_categories(user["id"])
    logger.debug(f"[GET /categories/tree] Fetched {len(categories)} categories")

    all_subcategories = db.get_subcategories()
    logger.debug(
        f"[GET /categories/tree] Fetched {len(all_subcategories)} subcategories"
    )

    # Group subcategories by category_id
    subcategories_by_category = {}
    for sub in all_subcategories:
        cat_id = sub["category_id"]
        if cat_id not in subcategories_by_category:
            subcategories_by_category[cat_id] = []
        subcategories_by_category[cat_id].append(SubcategoryResponse(**sub))

    # Build tree
    tree = []
    for cat in categories:
        cat_response = CategoryWithSubcategories(
            **cat, subcategories=subcategories_by_category.get(cat["id"], [])
        )
        tree.append(cat_response)

    logger.info(
        f"[GET /categories/tree] Returning {len(tree)} categories with subcategories"
    )
    return CategoriesTreeResponse(items=tree, total=len(tree))


@router.get("/{category_id}", response_model=CategoryResponse)
async def get_category(
    category_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Get a single category by ID."""
    category = db.get_category_by_id(category_id)
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")

    # Check access (system categories or user's own)
    if category["user_id"] is not None and category["user_id"] != user["id"]:
        raise HTTPException(
            status_code=403, detail="Not authorized to access this category"
        )

    return CategoryResponse(**category)


@router.post("", response_model=CategoryResponse, status_code=201)
async def create_category(
    category: CategoryCreate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Create a new user category."""
    category_data = {
        **category.model_dump(),
        "user_id": user["id"],
        "is_default": False,
    }
    created = db.create_category(category_data)
    return CategoryResponse(**created)


@router.patch("/{category_id}", response_model=CategoryResponse)
async def update_category(
    category_id: str,
    category: CategoryUpdate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Update a user category (cannot update system categories)."""
    existing = db.get_category_by_id(category_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Category not found")

    # Only user's own categories can be updated
    if existing["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Cannot update this category")

    # Update only provided fields
    update_data = category.model_dump(exclude_unset=True)
    updated = db.update_category(category_id, update_data)

    if not updated:
        raise HTTPException(status_code=500, detail="Failed to update category")

    return CategoryResponse(**updated)


@router.delete("/{category_id}", response_model=SuccessResponse)
async def delete_category(
    category_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Delete a user category. Transactions are reassigned to 'Uncategorized'."""
    existing = db.get_category_by_id(category_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Category not found")

    # Only user's own categories can be deleted
    if existing["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Cannot delete this category")

    # Reassign transactions using this category to "Uncategorized"
    uncategorized = db.get_user_category_by_name(user["id"], "Uncategorized")
    if uncategorized and uncategorized["id"] != category_id:
        db.reassign_transactions_category(
            user_id=user["id"],
            from_category_id=category_id,
            to_category_id=uncategorized["id"],
        )

    db.delete_category(category_id)
    return SuccessResponse(message="Category deleted successfully")


# ============================================================================
# Subcategories Endpoints
# ============================================================================


@router.get("/{category_id}/subcategories", response_model=SubcategoryListResponse)
async def list_subcategories(
    category_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """List subcategories for a specific category."""
    # Verify category exists and user has access
    category = db.get_category_by_id(category_id)
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")

    if category["user_id"] is not None and category["user_id"] != user["id"]:
        raise HTTPException(
            status_code=403, detail="Not authorized to access this category"
        )

    subcategories = db.get_subcategories(category_id)
    return SubcategoryListResponse(
        items=[SubcategoryResponse(**sub) for sub in subcategories],
        total=len(subcategories),
    )


@router.post(
    "/{category_id}/subcategories", response_model=SubcategoryResponse, status_code=201
)
async def create_subcategory(
    category_id: str,
    subcategory: SubcategoryCreate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Create a new subcategory under a category."""
    # Verify category exists and user has access
    category = db.get_category_by_id(category_id)
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")

    # Can only add subcategories to user's own categories
    if category["user_id"] != user["id"]:
        raise HTTPException(
            status_code=403, detail="Cannot add subcategory to this category"
        )

    # Override category_id from URL path
    subcategory_data = {
        **subcategory.model_dump(),
        "category_id": category_id,
        "user_id": user["id"],
        "is_default": False,
    }
    created = db.create_subcategory(subcategory_data)
    return SubcategoryResponse(**created)


@router.get("/subcategories/{subcategory_id}", response_model=SubcategoryResponse)
async def get_subcategory(
    subcategory_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Get a single subcategory by ID."""
    subcategory = db.get_subcategory_by_id(subcategory_id)
    if not subcategory:
        raise HTTPException(status_code=404, detail="Subcategory not found")

    # Check access
    if subcategory["user_id"] is not None and subcategory["user_id"] != user["id"]:
        raise HTTPException(
            status_code=403, detail="Not authorized to access this subcategory"
        )

    return SubcategoryResponse(**subcategory)


@router.patch("/subcategories/{subcategory_id}", response_model=SubcategoryResponse)
async def update_subcategory(
    subcategory_id: str,
    subcategory: SubcategoryUpdate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Update a subcategory (cannot update system subcategories)."""
    existing = db.get_subcategory_by_id(subcategory_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Subcategory not found")

    # Only user's own subcategories can be updated
    if existing["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Cannot update this subcategory")

    # Update only provided fields
    update_data = subcategory.model_dump(exclude_unset=True)
    updated = db.update_subcategory(subcategory_id, update_data)

    if not updated:
        raise HTTPException(status_code=500, detail="Failed to update subcategory")

    return SubcategoryResponse(**updated)


@router.delete("/subcategories/{subcategory_id}", response_model=SuccessResponse)
async def delete_subcategory(
    subcategory_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Delete a subcategory. Nulls out subcategory_id on existing transactions."""
    existing = db.get_subcategory_by_id(subcategory_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Subcategory not found")

    # Only user's own subcategories can be deleted
    if existing["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Cannot delete this subcategory")

    # Null out subcategory_id on transactions that use this subcategory
    db.clear_transaction_subcategory(user_id=user["id"], subcategory_id=subcategory_id)

    db.delete_subcategory(subcategory_id)
    return SuccessResponse(message="Subcategory deleted successfully")


# ============================================================================
# Categorization Rules Endpoints
# ============================================================================


@router.get("/rules", response_model=CategorizationRuleListResponse)
async def list_rules(
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """List all categorization rules for the user."""
    rules = db.get_categorization_rules(user["id"])
    return CategorizationRuleListResponse(
        items=[CategorizationRuleResponse(**r) for r in rules],
        total=len(rules),
    )


@router.post("/rules", response_model=CategorizationRuleResponse, status_code=201)
async def create_rule(
    rule: CategorizationRuleCreate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Create a new categorization rule."""
    valid_fields = {"payee", "description", "memo"}
    if rule.match_field not in valid_fields:
        raise HTTPException(
            status_code=400,
            detail=f"match_field must be one of: {', '.join(valid_fields)}",
        )

    # Verify category belongs to user
    category = db.get_category_by_id(rule.category_id)
    if not category or category["user_id"] != user["id"]:
        raise HTTPException(status_code=404, detail="Category not found")

    rule_data = {
        **rule.model_dump(),
        "user_id": user["id"],
    }
    created = db.create_categorization_rule(rule_data)
    return CategorizationRuleResponse(**created)


@router.delete("/rules/{rule_id}", response_model=SuccessResponse)
async def delete_rule(
    rule_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Delete a categorization rule."""
    rule = db.get_categorization_rule_by_id(rule_id)
    if not rule:
        raise HTTPException(status_code=404, detail="Rule not found")

    if rule["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    db.delete_categorization_rule(rule_id)
    return SuccessResponse(message="Rule deleted successfully")


# ============================================================================
# Manual Recategorization Endpoint
# ============================================================================


@router.patch(
    "/transactions/{transaction_id}/categorize", response_model=SuccessResponse
)
async def manual_categorize_transaction(
    transaction_id: str,
    request: ManualCategorizationRequest,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Manually categorize a transaction. Optionally creates a rule for future transactions."""
    # Verify transaction ownership
    txn = db.get_simplefin_transaction_by_id(transaction_id)
    if not txn:
        raise HTTPException(status_code=404, detail="Transaction not found")
    if txn["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Update the transaction
    updated = db.update_transaction_category(
        transaction_id=transaction_id,
        category_id=request.category_id,
        subcategory_id=request.subcategory_id,
        categorization_source="manual",
    )

    if not updated:
        raise HTTPException(status_code=500, detail="Failed to update transaction")

    # Optionally create a rule based on the transaction's payee
    if request.create_rule and request.category_id and txn.get("payee"):
        db.create_categorization_rule(
            {
                "user_id": user["id"],
                "match_field": "payee",
                "match_value": txn["payee"],
                "category_id": request.category_id,
                "subcategory_id": request.subcategory_id,
            }
        )

    return SuccessResponse(message="Transaction categorized successfully")


# ============================================================================
# AI Categorization Endpoint
# ============================================================================


@router.post("/ai/categorize", response_model=CategorizationResponse)
async def categorize_with_ai(
    request: CategorizationRequest,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Categorize transactions using rules first, then Claude AI.

    Applies user-defined categorization rules before sending remaining
    transactions to Claude AI for categorization.
    """
    logger.info(
        f"[POST /categories/ai/categorize] User: {user['id']}, Transaction IDs: {request.transaction_ids}, Force: {request.force}"
    )

    try:
        categorization_service = get_categorization_service(db)
        result = categorization_service.categorize_transactions(
            user_id=user["id"],
            transaction_ids=request.transaction_ids,
            force=request.force,
        )
        logger.info(
            f"[POST /categories/ai/categorize] Success: {result['categorized_count']} categorized, {result['failed_count']} failed"
        )
        return CategorizationResponse(**result)
    except ValueError as e:
        logger.error(f"[POST /categories/ai/categorize] ValueError: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        logger.error(f"[POST /categories/ai/categorize] Exception: {str(e)}")
        import traceback

        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Categorization failed: {str(e)}")
