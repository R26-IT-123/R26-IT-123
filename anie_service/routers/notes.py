from fastapi import APIRouter, Depends
from typing import Optional

from schemas.note import (
    AddCommentRequest,
    CommentItem,
    DownloadResponse,
    NoteDetail,
    NoteListItem,
    PublishNoteResponse,
    PurchaseNoteResponse,
    ToggleLikeResponse,
    ValidateNoteRequest,
    ValidateNoteResponse,
    WalletResponse,
)
from services.auth import get_current_user, get_optional_user
from services import note_service

router = APIRouter(prefix="/api/anie", tags=["ANIE Notes"])


@router.post("/validate-note", response_model=ValidateNoteResponse)
async def validate_note(
    body: ValidateNoteRequest,
    user: dict = Depends(get_current_user),
):
    uploader_name = user.get("name") or user.get("email") or "Anonymous"
    return await note_service.validate_note(
        user_id       = user["uid"],
        uploader_name = uploader_name,
        title         = body.title,
        subject       = body.subject,
        topic         = body.topic,
        file_urls     = body.file_urls,
    )


@router.post("/generate-topic-pdf/{note_id}", response_model=PublishNoteResponse)
async def generate_topic_pdf(
    note_id: str,
    user: dict = Depends(get_current_user),
):
    return await note_service.publish_note(
        note_id = note_id,
        user_id = user["uid"],
    )


@router.get("/wallet", response_model=WalletResponse)
def get_wallet(
    user: dict = Depends(get_current_user),
):
    return note_service.get_wallet_balance(user_id=user["uid"])


@router.get("/notes", response_model=list[NoteListItem])
def list_notes(
    subject: Optional[str] = None,
    topic:   Optional[str] = None,
    user:    Optional[dict] = Depends(get_optional_user),
):
    viewer_id = user["uid"] if user else None
    return note_service.list_published_notes(subject=subject, topic=topic, viewer_id=viewer_id)


@router.get("/notes/{note_id}", response_model=NoteDetail)
def get_note(
    note_id: str,
    user: Optional[dict] = Depends(get_optional_user),
):
    viewer_id = user["uid"] if user else None
    return note_service.get_note_detail(note_id=note_id, viewer_id=viewer_id)


@router.post("/notes/{note_id}/purchase", response_model=PurchaseNoteResponse)
async def purchase_note(
    note_id: str,
    user: dict = Depends(get_current_user),
):
    return note_service.purchase_note(note_id=note_id, user_id=user["uid"])


@router.post("/notes/{note_id}/download", response_model=DownloadResponse)
async def download_note(
    note_id: str,
    user: dict = Depends(get_current_user),
):
    return note_service.increment_download(note_id=note_id)


@router.post("/notes/{note_id}/like", response_model=ToggleLikeResponse)
async def toggle_note_like(
    note_id: str,
    user: dict = Depends(get_current_user),
):
    return note_service.toggle_like(note_id=note_id, user_id=user["uid"])


@router.get("/notes/{note_id}/comments", response_model=list[CommentItem])
def get_note_comments(note_id: str):
    return note_service.list_comments(note_id=note_id)


@router.post("/notes/{note_id}/comments", response_model=CommentItem)
async def post_note_comment(
    note_id: str,
    body: AddCommentRequest,
    user: dict = Depends(get_current_user),
):
    uploader_name = user.get("name") or user.get("email") or "Anonymous"
    return note_service.add_comment(
        note_id  = note_id,
        user_id  = user["uid"],
        user_name= uploader_name,
        text     = body.text,
    )
