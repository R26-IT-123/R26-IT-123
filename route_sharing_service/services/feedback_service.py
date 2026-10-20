from __future__ import annotations

import logging
import os
from datetime import datetime, timezone

from fastapi import HTTPException, status
from google.cloud.firestore_v1 import FieldFilter

from schemas.feedback import FeedbackSubmit
from services.firebase import get_firestore_client

logger = logging.getLogger(__name__)

_FEEDBACK_COL = "routesharing_ride_feedback"
_SUMMARIES_COL = "routesharing_ride_summaries"
_DRIVER_PROFILES_COL = "routesharing_driver_profiles"
_SESSIONS_COL = "routesharing_ride_sessions"

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")


def submit_feedback(passenger_id: str, data: FeedbackSubmit) -> dict:
    db = get_firestore_client()

    existing = list(
        db.collection(_FEEDBACK_COL)
        .where(filter=FieldFilter("ride_session_id", "==", data.ride_session_id))
        .where(filter=FieldFilter("passenger_id", "==", passenger_id))
        .limit(1)
        .stream()
    )
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Feedback already submitted for this session.")

    now = datetime.now(timezone.utc)
    feedback_doc = {
        "ride_session_id": data.ride_session_id,
        "passenger_id": passenger_id,
        "driver_id": data.driver_id,
        "overall_rating": data.overall_rating,
        "comment": data.comment,
        "submitted_at": now,
    }
    _, ref = db.collection(_FEEDBACK_COL).add(feedback_doc)
    feedback_doc["id"] = ref.id

    # Always regenerate the driver-level AI summary from all comments so far
    try:
        _regenerate_driver_summary(db, data.driver_id)
    except Exception as exc:
        logger.warning("Driver summary regeneration failed: %s", exc)

    _try_auto_generate_summary(db, data.ride_session_id)

    return feedback_doc


def _try_auto_generate_summary(db, ride_session_id: str) -> None:
    try:
        session_doc = db.collection(_SESSIONS_COL).document(ride_session_id).get()
        if not session_doc.exists:
            return
        passenger_ids = session_doc.to_dict().get("passenger_ids", [])
        if not passenger_ids:
            return

        submitted = list(
            db.collection(_FEEDBACK_COL)
            .where(filter=FieldFilter("ride_session_id", "==", ride_session_id))
            .stream()
        )
        submitted_ids = {s.to_dict().get("passenger_id") for s in submitted}

        if submitted_ids >= set(passenger_ids):
            existing_summary = list(
                db.collection(_SUMMARIES_COL)
                .where(filter=FieldFilter("ride_session_id", "==", ride_session_id))
                .limit(1)
                .stream()
            )
            if not existing_summary:
                generate_ai_summary(ride_session_id)
    except Exception as exc:
        logger.warning("Auto-summary generation failed: %s", exc)


def _regenerate_driver_summary(db, driver_id: str) -> None:
    all_docs = list(
        db.collection(_FEEDBACK_COL)
        .where(filter=FieldFilter("driver_id", "==", driver_id))
        .stream()
    )
    if not all_docs:
        return

    feedbacks = [doc.to_dict() or {} for doc in all_docs]
    avg_rating = sum(f.get("overall_rating", 0) for f in feedbacks) / len(feedbacks)
    comments = [f.get("comment", "").strip() for f in feedbacks if f.get("comment", "").strip()]

    ai_summary = _call_gemini(
        avg_rating=avg_rating,
        comments=comments,
        feedback_count=len(feedbacks),
    )

    db.collection(_DRIVER_PROFILES_COL).document(driver_id).set(
        {"ai_summary": ai_summary, "last_summary_at": datetime.now(timezone.utc)},
        merge=True,
    )


def generate_ai_summary(ride_session_id: str) -> dict:
    db = get_firestore_client()

    feedback_docs = list(
        db.collection(_FEEDBACK_COL)
        .where(filter=FieldFilter("ride_session_id", "==", ride_session_id))
        .stream()
    )

    if not feedback_docs:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No feedback found for this session.")

    feedbacks = [doc.to_dict() or {} for doc in feedback_docs]
    driver_id = feedbacks[0].get("driver_id", "")

    avg_rating = sum(f.get("overall_rating", 0) for f in feedbacks) / len(feedbacks)
    comments = [f.get("comment", "") for f in feedbacks if f.get("comment", "").strip()]

    ai_summary = _call_gemini(
        avg_rating=avg_rating,
        comments=comments,
        feedback_count=len(feedbacks),
    )

    now = datetime.now(timezone.utc)
    summary_doc = {
        "ride_session_id": ride_session_id,
        "driver_id": driver_id,
        "ai_summary": ai_summary,
        "avg_rating": round(avg_rating, 2),
        "generated_at": now,
    }
    _, ref = db.collection(_SUMMARIES_COL).add(summary_doc)
    summary_doc["id"] = ref.id

    _update_driver_profile(db, driver_id, avg_rating)

    return summary_doc


def _call_gemini(avg_rating: float, comments: list[str], feedback_count: int) -> str:
    fallback = (
        f"Passengers rated this driver {avg_rating:.1f} out of 5 based on {feedback_count} ride{'s' if feedback_count != 1 else ''}."
    )

    if not GEMINI_API_KEY:
        return fallback

    try:
        import google.generativeai as genai
        genai.configure(api_key=GEMINI_API_KEY)
        model = genai.GenerativeModel("gemini-2.5-flash")

        comments_text = "\n".join(f'- "{c}"' for c in comments) if comments else "No written comments."

        prompt = (
            f"Write a neutral 2–3 sentence summary for a carpooling driver profile based on passenger feedback.\n"
            f"Data from {feedback_count} passenger{'s' if feedback_count != 1 else ''}:\n"
            f"- Average star rating: {avg_rating:.1f}/5\n"
            f"- Passenger comments:\n{comments_text}\n\n"
            "Write in third person. Be concise and honest. Do not include a heading or label."
        )

        response = model.generate_content(prompt)
        return response.text.strip()
    except Exception as exc:
        logger.warning("Gemini AI call failed: %s", exc)
        return fallback


def _update_driver_profile(db, driver_id: str, session_avg: float) -> None:
    ref = db.collection(_DRIVER_PROFILES_COL).document(driver_id)
    doc = ref.get()
    now = datetime.now(timezone.utc)

    if doc.exists:
        existing = doc.to_dict() or {}
        total_rides = existing.get("total_rides", 0) + 1
        old_avg = existing.get("overall_avg_rating", session_avg)
        new_avg = round((old_avg * (total_rides - 1) + session_avg) / total_rides, 2)
        ref.update({
            "overall_avg_rating": new_avg,
            "total_rides": total_rides,
            "last_updated": now,
        })
    else:
        ref.set({
            "driver_id": driver_id,
            "overall_avg_rating": round(session_avg, 2),
            "total_rides": 1,
            "last_updated": now,
        })


def get_driver_rating_profile(driver_id: str) -> dict:
    db = get_firestore_client()

    doc = db.collection(_DRIVER_PROFILES_COL).document(driver_id).get()
    profile = doc.to_dict() if doc.exists else {}

    summary_docs = list(
        db.collection(_SUMMARIES_COL)
        .where(filter=FieldFilter("driver_id", "==", driver_id))
        .stream()
    )
    summaries = []
    for s in summary_docs:
        d = s.to_dict() or {}
        d["id"] = s.id
        summaries.append(d)
    summaries.sort(key=lambda x: x.get("generated_at") or datetime.min.replace(tzinfo=timezone.utc), reverse=True)
    summaries = summaries[:3]

    return {
        "driver_id": driver_id,
        "overall_avg_rating": profile.get("overall_avg_rating", 0.0),
        "total_rides": profile.get("total_rides", 0),
        "ai_summary": profile.get("ai_summary"),
        "recent_summaries": summaries,
        "last_updated": profile.get("last_updated"),
    }


def get_driver_feedback_entries(driver_id: str) -> list[dict]:
    db = get_firestore_client()
    docs = list(
        db.collection(_FEEDBACK_COL)
        .where(filter=FieldFilter("driver_id", "==", driver_id))
        .stream()
    )
    entries = []
    for doc in docs:
        d = doc.to_dict() or {}
        d["id"] = doc.id
        entries.append(d)
    entries.sort(key=lambda x: x.get("submitted_at") or datetime.min.replace(tzinfo=timezone.utc), reverse=True)
    return entries[:50]


def get_route_latest_summary(route_id: str) -> dict:
    db = get_firestore_client()

    raw_sessions = list(
        db.collection(_SESSIONS_COL)
        .where(filter=FieldFilter("route_id", "==", route_id))
        .where(filter=FieldFilter("status", "==", "completed"))
        .stream()
    )
    if not raw_sessions:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No completed sessions for this route.")
    raw_sessions.sort(
        key=lambda s: (s.to_dict() or {}).get("end_time") or datetime.min.replace(tzinfo=timezone.utc),
        reverse=True,
    )
    session_docs = raw_sessions[:1]

    session_id = session_docs[0].id

    summary_docs = list(
        db.collection(_SUMMARIES_COL)
        .where(filter=FieldFilter("ride_session_id", "==", session_id))
        .limit(1)
        .stream()
    )
    if not summary_docs:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No AI summary yet for this route.")

    data = summary_docs[0].to_dict() or {}
    data["id"] = summary_docs[0].id
    return data
