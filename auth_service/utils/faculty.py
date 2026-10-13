FACULTY_MAP: dict[str, str] = {
    "it": "Information Technology",
    "en": "Engineering",
    "bm": "Business Management",
    "cs": "Computing Science",
    "sc": "Science",
    "ar": "Architecture",
    "qu": "Quantity Surveying",
    "me": "Mechanical Engineering",
    "ci": "Civil Engineering",
    "ee": "Electrical Engineering",
}


def detect_faculty(email: str) -> str:
    """Derive faculty from the first two characters of the SLIIT email local part."""
    local = email.split("@")[0].lower()
    prefix = local[:2]
    return FACULTY_MAP.get(prefix, "Unknown Faculty")


def extract_student_id(email: str) -> str:
    """Return the uppercase local part as the student ID (e.g. IT21326240)."""
    return email.split("@")[0].upper()
