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
        monthly_budget=request.monthly_budget
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
    logger.debug(f"[GET /categories/tree] Fetched {len(all_subcategories)} subcategories")

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
            **cat,
            subcategories=subcategories_by_category.get(cat["id"], [])
        )
        tree.append(cat_response)

    logger.info(f"[GET /categories/tree] Returning {len(tree)} categories with subcategories")
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
        raise HTTPException(status_code=403, detail="Not authorized to access this category")

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
        "is_system": False,
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

    # Only user's own non-system categories can be updated
    if existing["user_id"] != user["id"] or existing["is_system"]:
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
    """Delete a user category (cannot delete system categories)."""
    existing = db.get_category_by_id(category_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Category not found")

    # Only user's own non-system categories can be deleted
    if existing["user_id"] != user["id"] or existing["is_system"]:
        raise HTTPException(status_code=403, detail="Cannot delete this category")

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
        raise HTTPException(status_code=403, detail="Not authorized to access this category")

    subcategories = db.get_subcategories(category_id)
    return SubcategoryListResponse(
        items=[SubcategoryResponse(**sub) for sub in subcategories],
        total=len(subcategories),
    )


@router.post("/{category_id}/subcategories", response_model=SubcategoryResponse, status_code=201)
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
        raise HTTPException(status_code=403, detail="Cannot add subcategory to this category")

    # Override category_id from URL path
    subcategory_data = {
        **subcategory.model_dump(),
        "category_id": category_id,
        "user_id": user["id"],
        "is_system": False,
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
        raise HTTPException(status_code=403, detail="Not authorized to access this subcategory")

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

    # Only user's own non-system subcategories can be updated
    if existing["user_id"] != user["id"] or existing["is_system"]:
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
    """Delete a subcategory (cannot delete system subcategories)."""
    existing = db.get_subcategory_by_id(subcategory_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Subcategory not found")

    # Only user's own non-system subcategories can be deleted
    if existing["user_id"] != user["id"] or existing["is_system"]:
        raise HTTPException(status_code=403, detail="Cannot delete this subcategory")

    db.delete_subcategory(subcategory_id)
    return SuccessResponse(message="Subcategory deleted successfully")


# ============================================================================
# AI Categorization Endpoint
# ============================================================================


@router.post("/ai/categorize", response_model=CategorizationResponse)
async def categorize_with_ai(
    request: CategorizationRequest,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Categorize transactions using Claude AI.

    This endpoint uses Claude to intelligently categorize transactions based on
    their description, payee, and amount. It can categorize specific transactions
    or all uncategorized transactions.
    """
    logger.info(f"[POST /categories/ai/categorize] User: {user['id']}, Transaction IDs: {request.transaction_ids}, Force: {request.force}")

    try:
        categorization_service = get_categorization_service(db)
        result = categorization_service.categorize_transactions(
            user_id=user["id"],
            transaction_ids=request.transaction_ids,
            force=request.force,
        )
        logger.info(f"[POST /categories/ai/categorize] Success: {result['categorized_count']} categorized, {result['failed_count']} failed")
        return CategorizationResponse(**result)
    except ValueError as e:
        logger.error(f"[POST /categories/ai/categorize] ValueError: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        logger.error(f"[POST /categories/ai/categorize] Exception: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Categorization failed: {str(e)}")
