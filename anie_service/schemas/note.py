from pydantic import BaseModel, Field
from typing import Optional


class ValidateNoteRequest(BaseModel):
    title:     str         = Field(..., min_length=3, max_length=200)
    subject:   str         = Field(..., description="Subject name, e.g. MTIT or SQA")
    topic:     str         = Field(..., description="Topic name — must match GET /anie/topics")
    file_urls: list[str]   = Field(..., min_length=1, description="Firebase Storage download URLs")


class ValidateNoteResponse(BaseModel):
    note_id:          str
    score:            float
    level:            str
    level_confidence: float
    is_approved:      bool
    tokens_earned:    int
    rejection_reason: Optional[str]
    word_count:       int
    keywords_found:   list[str]
    warning:          Optional[str]


class PublishNoteResponse(BaseModel):
    note_id:       str
    topic_pdf_url: str
    tokens_earned: int


class NoteListItem(BaseModel):
    note_id:            str
    title:              str
    subject:            str
    topic:              str
    score:              float
    level:              str
    uploader_id:        str
    uploader_name:      str
    uploader_photo_url: Optional[str]
    topic_pdf_url:      Optional[str]
    download_count:     int
    like_count:         int
    comment_count:      int
    liked_by_me:        bool
    purchased_by_me:    bool
    created_at:         str


class NoteDetail(NoteListItem):
    extracted_text: str
    note_word_count: int
    original_urls: list[str]


class TopicItem(BaseModel):
    subject: str
    topic:   str
    chunks:  int


class DownloadResponse(BaseModel):
    download_count: int


class WalletResponse(BaseModel):
    balance: int


class PurchaseNoteResponse(BaseModel):
    note_id:       str
    purchased:     bool
    balance:       int
    topic_pdf_url: Optional[str]


class ToggleLikeResponse(BaseModel):
    liked:      bool
    like_count: int


class CommentItem(BaseModel):
    comment_id: str
    user_id:    str
    user_name:  str
    text:       str
    created_at: str


class AddCommentRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=500)
