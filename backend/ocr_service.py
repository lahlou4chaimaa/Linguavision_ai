from functools import lru_cache

import easyocr


@lru_cache(maxsize=1)
def get_reader() -> easyocr.Reader:
    """
    Create the EasyOCR reader only once.

    The model is loaded when the first OCR request is received.
    """
    return easyocr.Reader(
        ["en", "fr"],
        gpu=False,
        verbose=False,
    )


def extract_text(image_path: str) -> str:
    """
    Extract text from an image.

    Supports English and French Latin-script text.
    """
    reader = get_reader()

    results = reader.readtext(
        image_path,
        detail=1,
        paragraph=True,
    )

    texts = []

    for result in results:
        if len(result) >= 2:
            text = str(result[1]).strip()

            if text:
                texts.append(text)

    return "\n".join(texts).strip()