"""Budget templates router (Phase 2)."""

from fastapi import APIRouter, Depends, HTTPException

from app.database import Database
from app.dependencies import get_current_user, get_database
from app.logging_config import get_logger
from app.schemas.budget_template import (
    BudgetTemplateCreate,
    BudgetTemplateUpdate,
    BudgetTemplateResponse,
    BudgetTemplateListResponse,
    CategoryBudgetCreate,
    CategoryBudgetUpdate,
    CategoryBudgetResponse,
    SubcategoryBudgetCreate,
    SubcategoryBudgetUpdate,
    SubcategoryBudgetResponse,
    BudgetPeriodCreate,
    BudgetPeriodResponse,
    BudgetPeriodListResponse,
    TemplateWithCategories,
)
from app.schemas.common import SuccessResponse


router = APIRouter(prefix="/budget-templates", tags=["Budget Templates"])
logger = get_logger("budget_templates")


# ============================================================================
# Budget Resolution (Get budget for month)
# ============================================================================


@router.get("/for-month", response_model=dict)
async def get_budget_for_month(
    year: int,
    month: int,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Get budget for a specific month with spending data.

    Implements inheritance logic:
    - If user has period override for this month → use that template
    - Otherwise → use default template

    Returns template + categories + subcategories + spending.
    """
    logger.info(f"[GET /for-month] User: {user['id']}, year: {year}, month: {month}")

    if month < 1 or month > 12:
        raise HTTPException(status_code=400, detail="Month must be between 1 and 12")

    budget_data = db.get_budget_for_month(user["id"], year, month)

    if not budget_data:
        raise HTTPException(
            status_code=404,
            detail="No default budget template found. Create one first.",
        )

    return budget_data


# ============================================================================
# Budget Templates Endpoints
# ============================================================================


@router.get("", response_model=BudgetTemplateListResponse)
async def list_templates(
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """List all budget templates for the user."""
    logger.info(f"[GET /budget-templates] User: {user['id']}")

    templates = db.get_budget_templates(user["id"])

    logger.info(f"[GET /budget-templates] Returning {len(templates)} templates")
    return BudgetTemplateListResponse(
        items=[BudgetTemplateResponse(**t) for t in templates],
        total=len(templates),
    )


@router.get("/{template_id}", response_model=TemplateWithCategories)
async def get_template(
    template_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Get a budget template with its categories and subcategories."""
    template = db.get_budget_template(template_id)
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    # Check ownership
    if template["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Fetch categories and subcategories
    categories = db.get_budget_categories(template_id)
    subcategories = db.get_budget_subcategories(template_id)

    return TemplateWithCategories(
        **template,
        categories=[CategoryBudgetResponse(**c) for c in categories],
        subcategories=[SubcategoryBudgetResponse(**s) for s in subcategories],
    )


@router.post("", response_model=BudgetTemplateResponse, status_code=201)
async def create_template(
    template: BudgetTemplateCreate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Create a new budget template."""
    template_data = {
        **template.model_dump(),
        "user_id": user["id"],
    }
    created = db.create_budget_template(template_data)
    return BudgetTemplateResponse(**created)


@router.patch("/{template_id}", response_model=BudgetTemplateResponse)
async def update_template(
    template_id: str,
    template: BudgetTemplateUpdate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Update a budget template."""
    # Check ownership
    existing = db.get_budget_template(template_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Template not found")

    if existing["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Update
    update_data = template.model_dump(exclude_unset=True)
    updated = db.update_budget_template(template_id, update_data)

    if not updated:
        raise HTTPException(status_code=500, detail="Failed to update template")

    return BudgetTemplateResponse(**updated)


@router.delete("/{template_id}", response_model=SuccessResponse)
async def delete_template(
    template_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Delete a budget template."""
    # Check ownership
    existing = db.get_budget_template(template_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Template not found")

    if existing["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Cannot delete default template
    if existing.get("is_default"):
        raise HTTPException(status_code=400, detail="Cannot delete default template")

    # Delete
    db.delete_budget_template(template_id)
    return SuccessResponse(message="Template deleted successfully")


@router.post("/{template_id}/set-default", response_model=BudgetTemplateResponse)
async def set_default_template(
    template_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Set a template as the default."""
    # Check ownership
    existing = db.get_budget_template(template_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Template not found")

    if existing["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Set as default
    updated = db.update_budget_template(template_id, {"is_default": True})
    return BudgetTemplateResponse(**updated)


# ============================================================================
# Budget Categories Endpoints
# ============================================================================


@router.post("/{template_id}/categories", response_model=CategoryBudgetResponse, status_code=201)
async def create_category_budget(
    template_id: str,
    category_budget: CategoryBudgetCreate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Add a category budget to a template."""
    # Check template ownership
    template = db.get_budget_template(template_id)
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    if template["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Create category budget
    category_data = {
        **category_budget.model_dump(),
        "template_id": template_id,
    }
    created = db.create_budget_category(category_data)
    return CategoryBudgetResponse(**created)


@router.patch("/{template_id}/categories/{category_budget_id}", response_model=CategoryBudgetResponse)
async def update_category_budget(
    template_id: str,
    category_budget_id: str,
    category_budget: CategoryBudgetUpdate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Update a category budget."""
    # Check template ownership
    template = db.get_budget_template(template_id)
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    if template["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Update
    update_data = category_budget.model_dump(exclude_unset=True)
    updated = db.update_budget_category(category_budget_id, update_data)

    if not updated:
        raise HTTPException(status_code=404, detail="Category budget not found")

    return CategoryBudgetResponse(**updated)


@router.delete("/{template_id}/categories/{category_budget_id}", response_model=SuccessResponse)
async def delete_category_budget(
    template_id: str,
    category_budget_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Delete a category budget."""
    # Check template ownership
    template = db.get_budget_template(template_id)
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    if template["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Delete
    db.delete_budget_category(category_budget_id)
    return SuccessResponse(message="Category budget deleted successfully")


# ============================================================================
# Budget Subcategories Endpoints
# ============================================================================


@router.post("/{template_id}/subcategories", response_model=SubcategoryBudgetResponse, status_code=201)
async def create_subcategory_budget(
    template_id: str,
    subcategory_budget: SubcategoryBudgetCreate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Add a subcategory budget to a template."""
    # Check template ownership
    template = db.get_budget_template(template_id)
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    if template["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Create subcategory budget
    subcategory_data = {
        **subcategory_budget.model_dump(),
        "template_id": template_id,
    }
    created = db.create_budget_subcategory(subcategory_data)
    return SubcategoryBudgetResponse(**created)


@router.patch("/{template_id}/subcategories/{subcategory_budget_id}", response_model=SubcategoryBudgetResponse)
async def update_subcategory_budget(
    template_id: str,
    subcategory_budget_id: str,
    subcategory_budget: SubcategoryBudgetUpdate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Update a subcategory budget."""
    # Check template ownership
    template = db.get_budget_template(template_id)
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    if template["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Update
    update_data = subcategory_budget.model_dump(exclude_unset=True)
    updated = db.update_budget_subcategory(subcategory_budget_id, update_data)

    if not updated:
        raise HTTPException(status_code=404, detail="Subcategory budget not found")

    return SubcategoryBudgetResponse(**updated)


@router.delete("/{template_id}/subcategories/{subcategory_budget_id}", response_model=SuccessResponse)
async def delete_subcategory_budget(
    template_id: str,
    subcategory_budget_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Delete a subcategory budget."""
    # Check template ownership
    template = db.get_budget_template(template_id)
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    if template["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Delete
    db.delete_budget_subcategory(subcategory_budget_id)
    return SuccessResponse(message="Subcategory budget deleted successfully")


# ============================================================================
# Budget Periods Endpoints
# ============================================================================


@router.get("/periods", response_model=BudgetPeriodListResponse)
async def list_periods(
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """List all budget periods (monthly overrides)."""
    periods = db.get_budget_periods(user["id"])
    return BudgetPeriodListResponse(
        items=[BudgetPeriodResponse(**p) for p in periods],
        total=len(periods),
    )


@router.post("/periods", response_model=BudgetPeriodResponse, status_code=201)
async def create_period(
    period: BudgetPeriodCreate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Apply a template to a specific month."""
    # Check template ownership
    template = db.get_budget_template(period.template_id)
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    if template["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Parse period_month and convert to YYYY-MM-01 format
    period_month = f"{period.period_month}-01"

    # Create period
    period_data = {
        "user_id": user["id"],
        "template_id": period.template_id,
        "period_month": period_month,
    }
    created = db.create_budget_period(period_data)
    return BudgetPeriodResponse(**created)


@router.delete("/periods/{period_id}", response_model=SuccessResponse)
async def delete_period(
    period_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Delete a budget period (reverts to default template)."""
    # Check ownership via period
    period = db.get_budget_period(user["id"], period_id)
    if not period:
        raise HTTPException(status_code=404, detail="Period not found")

    # Delete
    db.delete_budget_period(period_id)
    return SuccessResponse(message="Period deleted successfully (reverted to default template)")
