from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session, joinedload
from app.database import get_db
from app.models import User, Image
from app.auth import get_current_user

router = APIRouter(prefix="/api/stats", tags=["stats"])

# 用于全局统计的有效分类(排除 Invalid)
STAT_CATEGORIES = [
    "Negative",
    "Positive L",
    "Positive I",
    "Positive L+I",
]

# PatientInfo 中用于统计的维度字段
PATIENT_DIMENSIONS = ["species", "age", "sex", "breed", "zip_code"]


@router.get("/global")
def get_global_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Global statistics across all users' test results.
    Only includes images that have patient_info and a valid classification
    (Negative, Positive L, Positive I, Positive L+I).
    For each patient info dimension, returns distribution per classification category.
    """
    images = (
        db.query(Image)
        .options(joinedload(Image.patient_info))
        .filter(Image.patient_info.has())
        .all()
    )

    categorized = []
    for img in images:
        final = img.manual_correction or img.cv_result
        if final in STAT_CATEGORIES:
            categorized.append((final, img.patient_info))

    total = len(categorized)
    if total == 0:
        return {
            "total": 0,
            "category_totals": {cat: 0 for cat in STAT_CATEGORIES},
            "dimensions": {
                dim: {cat: {} for cat in STAT_CATEGORIES}
                for dim in PATIENT_DIMENSIONS
            },
        }

    category_totals = {cat: 0 for cat in STAT_CATEGORIES}
    for final, _ in categorized:
        category_totals[final] += 1

    dimensions = {}
    for dim in PATIENT_DIMENSIONS:
        dimensions[dim] = {cat: {} for cat in STAT_CATEGORIES}
        for final, pi in categorized:
            value = getattr(pi, dim)
            if value:
                dist = dimensions[dim][final]
                dist[value] = dist.get(value, 0) + 1

    return {
        "total": total,
        "category_totals": category_totals,
        "dimensions": dimensions,
    }
