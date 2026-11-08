
import os
import traceback
from io import BytesIO
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Literal

import edge_tts
import ollama

from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel, Field

from ocr_service import extract_text


# ============================================================
# APPLICATION CONFIGURATION
# ============================================================

app = FastAPI(
    title="LinguaVision AI API",
    description="Backend for the LinguaVision AI language tutor",
    version="1.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:3b")


# ============================================================
# REQUEST AND RESPONSE MODELS
# ============================================================

class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=4000)


class TutorRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    native_language: str = "French"
    target_language: str = "English"
    level: str = "A1"
    learning_goal: str = "Daily communication"
    history: list[ChatMessage] = Field(default_factory=list)


class TutorResponse(BaseModel):
    reply: str
    model: str


class TranslationRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)
    target_language: str = Field(min_length=2, max_length=50)


class TranslationResponse(BaseModel):
    translated_text: str
    target_language: str
    model: str


class TTSRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)
    language: str = Field(min_length=2, max_length=50)


# ============================================================
# EDGE TTS VOICES
# ============================================================

# The voice is selected according to the target language.
# These are Edge TTS neural voices.

TTS_VOICES = {
    "english": "en-US-AvaNeural",
    "french": "fr-FR-VivienneMultilingualNeural",
    "arabic": "ar-SA-ZariyahNeural",
    "spanish": "es-ES-ElviraNeural",
    "german": "de-DE-KatjaNeural",
    "italian": "it-IT-ElsaNeural",
    "portuguese": "pt-PT-RaquelNeural",
    "chinese": "zh-CN-XiaoxiaoNeural",
    "japanese": "ja-JP-NanamiNeural",
    "korean": "ko-KR-SunHiNeural",
    "turkish": "tr-TR-EmelNeural",
    "russian": "ru-RU-SvetlanaNeural",
    "dutch": "nl-NL-FennaNeural",
}


def get_tts_voice(language: str) -> str:
    normalized_language = language.lower().strip()

    return TTS_VOICES.get(
        normalized_language,
        "en-US-AvaNeural",
    )


# ============================================================
# ROOT ENDPOINT
# ============================================================

@app.get("/")
def root():
    return {
        "message": "LinguaVision AI API is running",
        "model": OLLAMA_MODEL,
        "features": [
            "AI Tutor",
            "EasyOCR",
            "Translation",
            "Neural Text To Speech",
        ],
    }


# ============================================================
# HEALTH CHECK
# ============================================================

@app.get("/health")
def health():
    try:
        ollama.list()

        return {
            "status": "ok",
            "ollama": "connected",
            "model": OLLAMA_MODEL,
        }

    except Exception as error:
        raise HTTPException(
            status_code=503,
            detail=f"Ollama is not available: {str(error)}",
        )


# ============================================================
# OCR - IMAGE TEXT RECOGNITION
# ============================================================

@app.post("/api/ocr")
async def ocr_image(file: UploadFile = File(...)):

    allowed_types = {
        "image/jpeg",
        "image/png",
        "image/webp",
        "image/jpg",
    }

    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail="Unsupported image format.",
        )

    image_bytes = await file.read()

    if not image_bytes:
        raise HTTPException(
            status_code=400,
            detail="The uploaded image is empty.",
        )

    if len(image_bytes) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail="Maximum image size is 10 MB.",
        )

    temporary_path = None

    try:
        suffix = Path(file.filename or "image.jpg").suffix.lower()

        if suffix not in {".jpg", ".jpeg", ".png", ".webp"}:
            suffix = ".jpg"

        with NamedTemporaryFile(
            delete=False,
            suffix=suffix,
        ) as temporary_file:

            temporary_file.write(image_bytes)
            temporary_path = temporary_file.name

        text = extract_text(temporary_path)

        return {
            "text": text,
            "language": "en/fr",
        }

    except Exception as error:
        traceback.print_exc()

        raise HTTPException(
            status_code=500,
            detail=f"OCR failed: {str(error)}",
        )

    finally:
        if temporary_path:
            Path(temporary_path).unlink(missing_ok=True)


# ============================================================
# TRANSLATION - OLLAMA
# ============================================================

@app.post(
    "/api/translate",
    response_model=TranslationResponse,
)
def translate_text(request: TranslationRequest):

    text = request.text.strip()
    target_language = request.target_language.strip()

    if not text:
        raise HTTPException(
            status_code=400,
            detail="The text to translate is empty.",
        )

   
    system_prompt = f"""
    You are a professional literal translation engine.

    Your only task is to translate the source text into {target_language}.

    IMPORTANT:
    The source is text extracted from an image.
    It may be a sign, poster, slogan, advertisement, label or short message.

    Translate what is actually written.
    Do not guess the author's intention.
    Do not answer the text.
    Do not describe the image.

    TRANSLATION RULES:
    1. Translate every word faithfully.
    2. Preserve the original grammatical person.
    3. In French, "on" often means "we".
    Translate it as "we" when it expresses a general collective action.
    4. Never replace "we" with "I".
    5. Preserve the meaning of short expressions and signs.
    6. Preserve line breaks when possible.
    7. Preserve names, numbers and punctuation.
    8. Do not add or remove information.
    9. Return only the translation.

    EXAMPLES:

    French:
    ICI
    ON PARLE FRANÇAIS

    English:
    HERE
    WE SPEAK FRENCH

    French:
    ICI ON PARLE FRANÇAIS

    English:
    HERE WE SPEAK FRENCH

    French:
    OUVERT TOUS LES JOURS

    English:
    OPEN EVERY DAY

    French:
    Nous parlons français ici.

    English:
    We speak French here.

    Now translate the following text into {target_language}:

    <source>
    {text}
    </source>
    """


    try:
        result = ollama.chat(
            model=OLLAMA_MODEL,
            messages=[
                {
                    "role": "system",
                    "content": system_prompt,
                },
                {
                    "role": "user",
                    "content": text,
                },
            ],
            options={
                "temperature": 0,
            },
        )

        translated_text = result["message"]["content"].strip()

        if not translated_text:
            raise ValueError(
                "The translation model returned an empty response."
            )

        return TranslationResponse(
            translated_text=translated_text,
            target_language=target_language,
            model=OLLAMA_MODEL,
        )

    except Exception as error:
        traceback.print_exc()

        raise HTTPException(
            status_code=503,
            detail=f"Translation failed: {str(error)}",
        )


# ============================================================
# TEXT TO SPEECH - MICROSOFT EDGE TTS
# ============================================================

@app.post("/api/tts")
async def generate_speech(request: TTSRequest):
    text = request.text.strip()

    if not text:
        raise HTTPException(
            status_code=400,
            detail="Text cannot be empty.",
        )

    try:
        voice = get_tts_voice(request.language)

        temp_path = None

        try:
            with NamedTemporaryFile(
                delete=False,
                suffix=".mp3",
            ) as temp_file:
                temp_path = temp_file.name

            communicate = edge_tts.Communicate(
                text=text,
                voice=voice,
                rate="+0%",
                volume="+0%",
                pitch="+0Hz",
            )

            await communicate.save(temp_path)

            audio_bytes = Path(temp_path).read_bytes()

            if not audio_bytes:
                raise HTTPException(
                    status_code=500,
                    detail="Edge TTS generated an empty audio file.",
                )

            return Response(
                content=audio_bytes,
                media_type="audio/mpeg",
                headers={
                    "Content-Disposition": 'inline; filename="linguavision.mp3"',
                    "Cache-Control": "no-store",
                    "X-TTS-Voice": voice,
                    "Content-Length": str(len(audio_bytes)),
                },
            )

        finally:
            if temp_path:
                Path(temp_path).unlink(missing_ok=True)

    except HTTPException:
        raise

    except Exception as error:
        print("TTS ERROR:")
        traceback.print_exc()

        raise HTTPException(
            status_code=500,
            detail=f"TTS generation failed: {error}",
        )


# ============================================================
# AI TUTOR CHAT
# ============================================================


@app.post(
    "/api/tutor/chat",
    response_model=TutorResponse,
)
def tutor_chat(request: TutorRequest):

    system_prompt = f"""
You are LinguaVision AI, a natural and friendly language tutor.

STUDENT PROFILE:
- Native language: {request.native_language}
- Target language: {request.target_language}
- Current level: {request.level}
- Learning goal: {request.learning_goal}

YOUR MAIN OBJECTIVE:
Help the student learn {request.target_language}
through natural, realistic conversations.

LANGUAGE RULES:

1. During normal conversations, speak primarily in
   {request.target_language}.

2. Adapt your vocabulary and sentence structure to
   the student's level: {request.level}.

3. Do not randomly mix {request.native_language}
   and {request.target_language} in the same sentence.

4. Use {request.native_language} only when:
   - The student explicitly asks for an explanation.
   - The student does not understand something.
   - You need to explain a grammatical mistake.
   - A short translation would genuinely help.

5. If the student asks a question in their native language
   about a difficult concept, explain it clearly in
   their native language.

6. Never switch to an unrelated language.

NATURAL CONVERSATION:

- Speak like a real human language teacher.
- Be natural, patient and conversational.
- Avoid robotic expressions and repetitive introductions.
- Keep answers short and easy to understand.
- Ask only one relevant question at a time.
- Do not give long lectures during normal conversations.
- Do not repeat the student's entire message unnecessarily.
- Avoid unnecessary headings, lists and markdown.
- Make your responses suitable for speaking aloud.

CORRECTION RULES — STRICT PRIORITY:

Whenever the student writes or says a sentence containing
a grammatical, vocabulary or pronunciation-related
transcription mistake:

You MUST follow this exact structure:

1. Correct sentence:
Write the correct sentence in the target language.

2. Explanation in the native language:
Explain clearly and simply why the original sentence
was incorrect.

3. Natural example:
Give one additional example in the target language
and translate it into the native language.

4. Continue the conversation:
Ask one short relevant question in the target language.

NEVER provide only the corrected sentence.
NEVER omit the native-language explanation.
NEVER explain an English grammar mistake only in English.

Example:

Student:
I goed to school yesterday.

Correct sentence:
I went to school yesterday.

Explication en français:
Le verbe "go" est irrégulier.
Son passé est "went", et non "goed".

Another example:
I went to the supermarket yesterday.
Je suis allé au supermarché hier.

Your turn:
Where did you go yesterday?

This correction structure is mandatory whenever
the student makes a mistake.

"""

    messages = [
        {
            "role": "system",
            "content": system_prompt,
        }
    ]

    # Keep only the last 12 messages.
    for item in request.history[-12:]:
        messages.append({
            "role": item.role,
            "content": item.content,
        })

    # Add the current student message.
    messages.append({
        "role": "user",
        "content": request.message.strip(),
    })

    try:
        result = ollama.chat(
            model=OLLAMA_MODEL,
            messages=messages,
            options={
                "temperature": 0.4,
                "num_predict": 450,
            },
        )

        reply = result["message"]["content"].strip()

        if not reply:
            raise ValueError(
                "The AI returned an empty response."
            )

        return TutorResponse(
            reply=reply,
            model=OLLAMA_MODEL,
        )

    except Exception as error:
        traceback.print_exc()

        raise HTTPException(
            status_code=503,
            detail=(
                "Unable to generate a response. "
                "Check that Ollama is running and that "
                f"the model '{OLLAMA_MODEL}' is installed. "
                f"Details: {str(error)}"
            ),
        )
