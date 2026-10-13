import io
import logging
from pathlib import Path

import certifi
import fitz  # PyMuPDF
import httpx
import numpy as np
from PIL import Image

log = logging.getLogger(__name__)

IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tiff", ".tif"}

_ocr_reader = None


def _get_ocr_reader():
    global _ocr_reader
    if _ocr_reader is None:
        log.info("Initialising EasyOCR (first image upload) ...")
        import easyocr
        _ocr_reader = easyocr.Reader(["en"], gpu=False)
    return _ocr_reader


def _extract_from_pdf(data: bytes) -> str:
    doc   = fitz.open(stream=data, filetype="pdf")
    pages = [page.get_text() for page in doc]
    doc.close()
    return "\n".join(pages).strip()


def _extract_from_image(data: bytes) -> str:
    reader = _get_ocr_reader()
    img    = np.array(Image.open(io.BytesIO(data)).convert("RGB"))
    lines  = reader.readtext(img, detail=0)
    return " ".join(lines).strip()


def _detect_ext(url: str, content_type: str) -> str:
    url_ext = Path(url.split("?")[0]).suffix.lower()
    if url_ext:
        return url_ext
    ct = content_type.lower()
    if "pdf" in ct:
        return ".pdf"
    if "png" in ct:
        return ".png"
    if "jpeg" in ct or "jpg" in ct:
        return ".jpg"
    return ""


async def extract_all(file_urls: list[str]) -> str:
    """Download every URL, extract text, return one merged string."""
    parts: list[str] = []

    async with httpx.AsyncClient(timeout=60.0, verify=certifi.where()) as client:
        for url in file_urls:
            try:
                resp = await client.get(url)
                resp.raise_for_status()
            except Exception as exc:
                log.warning(f"Failed to download {url}: {exc}")
                continue

            data        = resp.content
            content_type = resp.headers.get("content-type", "")
            ext         = _detect_ext(url, content_type)

            if ext == ".pdf":
                text = _extract_from_pdf(data)
            elif ext in IMAGE_EXTS:
                text = _extract_from_image(data)
            else:
                log.warning(f"Unsupported file type '{ext}' for URL: {url}")
                continue

            if text.strip():
                parts.append(text.strip())

    return "\n\n".join(parts)
