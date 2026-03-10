from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload
from app.database import get_db
from app.models import User, UploadBatch, Image
from app.auth import get_current_user

router = APIRouter(prefix="/api/stats", tags=["stats"])

VALID_CATEGORIES = [
    "Negative",
    "Positive L",
    "Positive I",
    "Positive L+I",
    "Invalid",
]


@router.get("/batch/{batch_id}")
def get_batch_stats(
    batch_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Generate statistics for a batch."""
    batch = (
        db.query(UploadBatch)
        .filter(UploadBatch.id == batch_id, UploadBatch.user_id == current_user.id)
        .first()
    )
    if not batch:
        raise HTTPException(status_code=404, detail="Batch not found")

    images = (
        db.query(Image)
        .options(joinedload(Image.patient_info))
        .filter(Image.batch_id == batch_id)
        .all()
    )

    total = len(images)
    if total == 0:
        return {
            "batch_id": batch_id,
            "batch_name": batch.name,
            "total_images": 0,
            "distribution": {},
            "reading_coverage": {},
            "ai_comparison": None,
            "cv_comparison": None,
            "patient_summary": None,
        }

    # 统计最终结果分布（优先 manual_correction，其次 reading_result）
    final_distribution = {}
    ai_distribution = {}
    cv_distribution = {}
    correction_distribution = {}

    ai_count = 0
    cv_count = 0
    correction_count = 0
    ai_both_count = 0  # 同时有 AI 结果和手动修正
    cv_both_count = 0  # 同时有 CV 结果和手动修正

    for img in images:
        # AI reading distribution
        if img.reading_result:
            ai_count += 1
            ai_distribution[img.reading_result] = ai_distribution.get(img.reading_result, 0) + 1

        # CV reading distribution
        if img.cv_result:
            cv_count += 1
            cv_distribution[img.cv_result] = cv_distribution.get(img.cv_result, 0) + 1

        # Manual correction distribution
        if img.manual_correction:
            correction_count += 1
            correction_distribution[img.manual_correction] = (
                correction_distribution.get(img.manual_correction, 0) + 1
            )

        # AI + manual both exist
        if img.reading_result and img.manual_correction:
            ai_both_count += 1

        # CV + manual both exist
        if img.cv_result and img.manual_correction:
            cv_both_count += 1

        # Final result: manual_correction > reading_result > "Unclassified"
        final = img.manual_correction or img.reading_result or "Unclassified"
        final_distribution[final] = final_distribution.get(final, 0) + 1

    def _build_comparison(images, result_field, both_count):
        """Build comparison metrics between a prediction field and manual_correction.

        Args:
            images: list of Image objects
            result_field: attribute name on Image to use as prediction ("reading_result" or "cv_result")
            both_count: number of images with both prediction and manual_correction
        """
        if both_count == 0:
            return None

        match_count = 0
        confusion = {}

        for img in images:
            predicted = getattr(img, result_field)
            manual = img.manual_correction
            if predicted and manual:
                if predicted == manual:
                    match_count += 1
                key = f"{predicted}||{manual}"
                confusion[key] = confusion.get(key, 0) + 1

        # Reshape confusion matrix into structured format
        confusion_matrix = []
        for key, count in confusion.items():
            pred, actual = key.split("||")
            confusion_matrix.append({
                "predicted": pred,
                "actual": actual,
                "count": count,
            })

        # Per-category precision and recall
        per_category = []
        for cat in VALID_CATEGORIES:
            tp = 0
            fp = 0
            fn = 0
            for img in images:
                predicted = getattr(img, result_field)
                manual = img.manual_correction
                if predicted and manual:
                    if predicted == cat and manual == cat:
                        tp += 1
                    elif predicted == cat and manual != cat:
                        fp += 1
                    elif predicted != cat and manual == cat:
                        fn += 1

            precision = tp / (tp + fp) if (tp + fp) > 0 else None
            recall = tp / (tp + fn) if (tp + fn) > 0 else None
            f1 = (
                2 * precision * recall / (precision + recall)
                if precision is not None and recall is not None and (precision + recall) > 0
                else None
            )

            if tp + fp + fn > 0:
                per_category.append({
                    "category": cat,
                    "precision": round(precision, 4) if precision is not None else None,
                    "recall": round(recall, 4) if recall is not None else None,
                    "f1_score": round(f1, 4) if f1 is not None else None,
                    "support": tp + fn,
                })

        return {
            "total_compared": both_count,
            "matches": match_count,
            "accuracy": round(match_count / both_count, 4) if both_count > 0 else None,
            "confusion_matrix": confusion_matrix,
            "per_category": per_category,
        }

    # AI vs Manual comparison
    ai_comparison = _build_comparison(images, "reading_result", ai_both_count)
    # CV vs Manual comparison
    cv_comparison = _build_comparison(images, "cv_result", cv_both_count)

    # Patient info summary
    patient_summary = None
    patient_images = [img for img in images if img.patient_info]
    if patient_images:
        species_dist = {}
        sex_dist = {}
        for img in patient_images:
            pi = img.patient_info
            if pi.species:
                species_dist[pi.species] = species_dist.get(pi.species, 0) + 1
            if pi.sex:
                sex_dist[pi.sex] = sex_dist.get(pi.sex, 0) + 1
        patient_summary = {
            "total_with_patient_info": len(patient_images),
            "species_distribution": species_dist,
            "sex_distribution": sex_dist,
        }

    return {
        "batch_id": batch_id,
        "batch_name": batch.name,
        "total_images": total,
        "distribution": {
            "final": final_distribution,
            "ai_reading": ai_distribution,
            "cv_reading": cv_distribution,
            "manual_correction": correction_distribution,
        },
        "reading_coverage": {
            "ai_read": ai_count,
            "cv_read": cv_count,
            "manually_corrected": correction_count,
            "ai_and_manual": ai_both_count,
            "cv_and_manual": cv_both_count,
            "unclassified": total - max(ai_count, cv_count, correction_count),
        },
        "ai_comparison": ai_comparison,
        "cv_comparison": cv_comparison,
        "patient_summary": patient_summary,
    }
