def calculate(score: float, semantic_score: float, keyword_score: float) -> tuple[int, bool, str | None]:
    """
    Returns (tokens_earned, is_approved, rejection_reason).
    Beginner notes (score > 10) are approved with 0 tokens.
    """
    if score >= 75:
        return 10, True, None
    if score >= 50:
        return 5, True, None
    if score >= 40:
        return 2, True, None
    if score > 10:
        return 0, True, None

    # Rejected — score <= 10
    if semantic_score < 30 and keyword_score < 30:
        reason = (
            "Your note does not cover the selected topic's lecture content "
            "and lacks the required technical terminology."
        )
    elif semantic_score < 30:
        reason = (
            "Your note does not adequately match the selected topic's "
            "lecture material. Please review the topic content and resubmit."
        )
    elif keyword_score < 30:
        reason = (
            "Your note lacks key technical terms expected for this topic. "
            "Try to include domain-specific concepts in your notes."
        )
    else:
        reason = (
            "Your note does not reach the minimum quality threshold for this topic. "
            "Please improve coverage and technical depth before resubmitting."
        )

    return 0, False, reason
