
import os
from typing import Literal

import ollama
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field


# ============================================================
# APPLICATION CONFIGURATION
# ============================================================

app = FastAPI(
    title="LinguaVision AI API",
    description="Backend for the LinguaVision AI language tutor",
    version="1.0.0",
)

# CORS configuration for Flutter Web development.
# In production, restrict allowed origins to trusted domains.
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


# ============================================================
# ROOT ENDPOINT
# ============================================================

@app.get("/")
def root():
    return {
        "message": "LinguaVision AI API is running",
        "model": OLLAMA_MODEL,
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
# AI TUTOR CHAT
# ============================================================

@app.post("/api/tutor/chat", response_model=TutorResponse)
def tutor_chat(request: TutorRequest):

    system_prompt = f"""
You are LinguaVision AI, a professional bilingual language tutor.

STUDENT PROFILE:
- Native language: {request.native_language}
- Target language: {request.target_language}
- Current level: {request.level}
- Learning goal: {request.learning_goal}

============================================================
IMPORTANT LANGUAGE POLICY
============================================================

You MUST use BOTH the target language and the native language.

For a student learning English whose native language is French:

- Use English for conversations, examples and practice.
- Use French to explain grammar, vocabulary and difficult concepts.
- Include French translations of important examples.
- Never give a complete grammar explanation only in English.
- Never switch to Spanish or another language unless requested.
- Adapt the English vocabulary and explanations to level {request.level}.

The French explanation is MANDATORY whenever the student asks
about grammar, vocabulary, sentence structure or language rules.

============================================================
GRAMMAR EXPLANATION FORMAT
============================================================

When the student asks about a grammar difference, ALWAYS use
the following structure:

1. THE RULE (IN ENGLISH)
Explain the grammar rule using simple English.

2. EXPLICATION EN FRANÇAIS
Explain the same rule in clear and simple French.

3. EXAMPLES
Give at least two examples in English.
Translate every example into French.

4. COMPARISON
Compare the expressions and explain when to use each one.
Include the explanation in both English and French.

5. YOUR TURN
Give the student one short exercise in English.
Explain the exercise instructions in French.

============================================================
CORRECTION POLICY
============================================================

- Correct mistakes politely.
- Show the student's original sentence.
- Provide the corrected sentence.
- Explain the reason in French.
- Give a natural English example.
- Never invent mistakes if the sentence is correct.

============================================================
CONVERSATION POLICY
============================================================

- Be patient and encouraging.
- Keep the conversation natural.
- Ask relevant follow-up questions.
- Do not make every simple conversation unnecessarily long.
- Use French when the student needs clarification.
- Encourage the student to answer in English.
- Do not ignore the student's native language preference.

Your main objective is to help the student understand English,
not simply translate sentences.
"""

    messages = [
        {
            "role": "system",
            "content": system_prompt,
        }
    ]

    # Keep only the last 12 messages to limit context size.
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
        )

        reply = result["message"]["content"].strip()

        if not reply:
            raise ValueError("The AI returned an empty response.")

        return TutorResponse(
            reply=reply,
            model=OLLAMA_MODEL,
        )

    except Exception as error:
        raise HTTPException(
            status_code=503,
            detail=(
                "Unable to generate a response. "
                "Check that Ollama is running and that "
                f"the model '{OLLAMA_MODEL}' is installed. "
                f"Details: {str(error)}"
            ),
        )
