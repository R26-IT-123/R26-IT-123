import json
import logging
import os
from pathlib import Path
from typing import Tuple

import numpy as np
from sentence_transformers import SentenceTransformer

log = logging.getLogger(__name__)

MODEL_DIR     = Path(os.getenv("MODEL_DIR", "../shortnotescore/model"))
CHUNK_SIZE    = 400
CHUNK_OVERLAP = 50
KEYWORD_CAP   = 80.0

_state: dict = {}


def load_models() -> None:
    log.info(f"Loading ANIE scoring models from {MODEL_DIR.resolve()} ...")

    _state["embedder"] = SentenceTransformer(
        "sentence-transformers/all-MiniLM-L6-v2"
    )
    _state["embeddings"] = np.load(str(MODEL_DIR / "embeddings.npy"))

    with open(MODEL_DIR / "faiss_metadata.json", encoding="utf-8") as f:
        _state["metadata"] = json.load(f)
    with open(MODEL_DIR / "topics.json", encoding="utf-8") as f:
        _state["topics"] = json.load(f)
    with open(MODEL_DIR / "topic_keywords.json", encoding="utf-8") as f:
        _state["topic_keywords"] = json.load(f)
    with open(MODEL_DIR / "topic_calibration.json", encoding="utf-8") as f:
        _state["topic_calibration"] = json.load(f)

    log.info(f"ANIE scoring ready — {len(_state['topics'])} topics loaded.")


def get_topics() -> list[dict]:
    return _state.get("topics", [])


def score_note(note_text: str, subject: str, topic: str) -> dict:
    sem_score               = _semantic_coverage(note_text, subject, topic)
    kw_score, found, missed = _keyword_coverage(note_text, subject, topic)
    final_score             = round(0.65 * sem_score + 0.35 * kw_score, 1)
    level, confidence       = _score_to_level(final_score)

    log.info(
        f"[{subject}] {topic} → semantic={sem_score} keywords={kw_score} "
        f"final={final_score} level={level} ({confidence}%)"
    )

    return {
        "score":            final_score,
        "level":            level,
        "level_confidence": confidence,
        "semantic_score":   sem_score,
        "keyword_score":    kw_score,
        "keywords_found":   found,
        "keywords_missed":  missed,
        "word_count":       len(note_text.split()),
    }


# ── internal helpers ──────────────────────────────────────────────────────────

def _chunk_text(text: str) -> list[str]:
    words = text.split()
    chunks, start = [], 0
    while start < len(words):
        segment = " ".join(words[start: start + CHUNK_SIZE])
        if len(segment.split()) >= 30:
            chunks.append(segment)
        start += CHUNK_SIZE - CHUNK_OVERLAP
    return chunks if chunks else [text]


def _semantic_coverage(note_text: str, subject: str, topic: str) -> float:
    meta    = _state["metadata"]
    all_emb = _state["embeddings"]
    key     = f"{subject}||{topic}"

    indices = [i for i, m in enumerate(meta) if m["subject"] == subject and m["topic"] == topic]
    if not indices:
        raise ValueError(f"No reference data for [{subject}] {topic}")

    ref_emb     = all_emb[indices]
    note_chunks = _chunk_text(note_text)
    note_emb    = _state["embedder"].encode(
        note_chunks, convert_to_numpy=True, normalize_embeddings=True
    )

    sims         = ref_emb @ note_emb.T
    best_per_ref = sims.max(axis=1)
    raw          = float(best_per_ref.mean())

    c        = _state["topic_calibration"].get(key, {})
    null_sim = c.get("null_sim", 0.35)
    max_sim  = c.get("max_sim",  0.65)
    span     = max_sim - null_sim

    score = (raw - null_sim) / span * 100 if span > 0 else 50.0
    return round(float(np.clip(score, 0.0, 100.0)), 1)


def _keyword_coverage(
    note_text: str, subject: str, topic: str
) -> Tuple[float, list[str], list[str]]:
    key      = f"{subject}||{topic}"
    keywords = _state["topic_keywords"].get(key, [])
    if not keywords:
        return 50.0, [], []

    note_lower = note_text.lower()
    found  = [kw for kw in keywords if kw.lower() in note_lower]
    missed = [kw for kw in keywords if kw.lower() not in note_lower]

    raw_pct    = len(found) / len(keywords) * 100
    normalised = min(raw_pct / KEYWORD_CAP * 100, 100.0)
    return round(normalised, 1), found, missed


def _score_to_level(score: float) -> Tuple[str, float]:
    if score < 35:
        level      = "Beginner"
        confidence = round(50.0 + (35.0 - score) / 35.0 * 49.0, 1)
    elif score < 65:
        level        = "Medium"
        mid_distance = abs(score - 50.0) / 15.0
        confidence   = round(50.0 + (1.0 - min(mid_distance, 1.0)) * 49.0, 1)
    else:
        level      = "Advanced"
        confidence = round(50.0 + (score - 65.0) / 35.0 * 49.0, 1)
    return level, min(confidence, 99.0)
