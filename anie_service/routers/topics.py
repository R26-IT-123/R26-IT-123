from fastapi import APIRouter

from schemas.note import TopicItem
from services.scorer import get_topics

router = APIRouter(prefix="/api/anie", tags=["ANIE Topics"])


@router.get("/topics", response_model=list[TopicItem])
def list_topics():
    return get_topics()
