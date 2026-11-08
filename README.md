# LinguaVision AI

**An AI-powered multilingual language learning application.**

LinguaVision AI is a language learning application designed to make learning more interactive, personalized, and accessible. It combines artificial intelligence, speech recognition, text-to-speech, and computer vision to help users improve their language skills through practical activities and real-time assistance.

The application allows learners to interact with an AI tutor, practice pronunciation, translate text from images, and track their learning progress.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Screenshots](#screenshots)
- [Technology Stack](#technology-stack)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running the Application](#running-the-application)
- [Database](#database)
- [AI Components](#ai-components)
- [Security](#security)
- [Roadmap](#roadmap)
- [Current Development Status](#current-development-status)
- [Author](#author)

---

## Overview

Learning a new language requires more than memorizing vocabulary and grammar. Learners also need opportunities to communicate, listen, pronounce words correctly, and practice in realistic situations.

LinguaVision AI addresses these needs through an intelligent learning environment.

Users can select their native language, target language, proficiency level, and learning preferences. The application then provides personalized learning assistance through an AI-powered tutor.

The project is designed with a modular architecture using Flutter for the client application, FastAPI for backend services, Ollama for local language model inference, and Supabase for authentication and data persistence.

---

## Features

### 1. AI Tutor

An interactive AI assistant that helps users practice their target language.

- Conversational language practice.
- Personalized responses based on the learner's level.
- Grammar and vocabulary corrections.
- Explanations in the learner's native language.
- Conversation history.
- Context-aware interactions.

### 2. Voice Interaction

Voice-based interaction to make language practice more natural.

- Speech recognition through the microphone.
- Text-to-speech responses.
- Support for different language voices.
- Listening and speaking practice.
- Integration with headset audio devices.

### 3. Camera Translation and OCR

An image-based translation feature that helps learners understand written content.

- Capture or upload an image.
- Extract text using Optical Character Recognition (OCR).
- Detect and process text from images.
- Translate extracted content.
- Support for practical language learning scenarios.

### 4. Vocabulary Learning

A dedicated space for vocabulary development.

Planned capabilities include:

- Vocabulary collections.
- Word definitions and translations.
- Personalized vocabulary lists.
- Learning progress and revision activities.

### 5. Learning Progress

The application uses a personalized learning profile to organize the learning experience.

Learner preferences include:

- Native language.
- Target language.
- Proficiency level (A1, A2, B1, B2, C1, C2).
- Learning objectives.
- Daily learning duration.

### 6. Interactive AI Avatar (Planned)

The project aims to introduce an animated AI tutor avatar to make conversations more immersive.

The objective is to support:

- Natural facial expressions.
- Eye blinking and head movements.
- Lip synchronization.
- Continuous avatar presence during conversations.
- More realistic speaking and listening interactions.

Kling AI is being evaluated for AI-generated avatar animation. Real-time interaction and API integration are still under development.

---

## Screenshots

Add application screenshots here as the interface evolves.

Suggested screenshots:

- Authentication screen.
- Learning preferences setup.
- Home dashboard.
- AI Tutor conversation.
- Camera translation.
- Conversation history.

---

## Technology Stack

| Component | Technology |
|---|---|
| Mobile application | Flutter / Dart |
| Backend API | Python / FastAPI |
| AI language model | Ollama |
| Language model | Llama 3.2 3B |
| Embeddings | Nomic Embed Text |
| Database and authentication | Supabase |
| Speech synthesis | Edge TTS |
| Speech recognition | Speech recognition integration |
| OCR | EasyOCR |
| API communication | REST API |
| Development environment | Windows |

### Main Technologies

**Flutter**

Used to build the application's user interface and manage navigation, screens, and user interactions.

**FastAPI**

Provides backend endpoints for AI conversations, OCR processing, and communication with local AI services.

**Ollama**

Runs language models locally, allowing the application to generate AI responses without depending entirely on external LLM APIs.

**Supabase**

Handles authentication, user profiles, and persistent application data.

**EasyOCR**

Extracts text from images to support the camera translation feature.

**Edge TTS**

Generates spoken responses using language-specific voices.

---

## Architecture

LinguaVision AI follows a client-server architecture.

```text
                 LINGUAVISION AI
                        |
          +-------------+-------------+
          |                           |
      Flutter App                Supabase
          |                    Authentication
          |                    User Profiles
          |                    Tutor History
          |
          | HTTP Requests
          |
       FastAPI Backend
          |
    +-----+------------------+
    |            |           |
    |            |           |
  Ollama      EasyOCR     Edge TTS
    |            |           |
    |            |           |
 AI Responses  Text        Voice
               Extraction  Generation
    |
    |
 Personalized
 AI Tutor
```

### Application Workflow

1. The user signs in through Supabase.
2. The user configures their language learning preferences.
3. Flutter sends requests to the FastAPI backend.
4. The backend processes the request.
5. Ollama generates contextual AI responses when required.
6. Edge TTS generates audio responses.
7. EasyOCR processes images submitted for text extraction.
8. Relevant conversation data is stored through Supabase.
9. Flutter displays the results to the learner.

---

## Project Structure

```text
linguavision_ai/
│
├── android/
├── assets/
├── backend/
│   ├── main.py
│   ├── ocr_service.py
│   ├── requirements.txt
│   └── .venv/
│
├── lib/
│   ├── main.dart
│   ├── screens/
│   ├── services/
│   ├── models/
│   └── widgets/
│
├── ios/
├── linux/
├── macos/
├── web/
├── windows/
│
├── test/
├── .gitignore
├── pubspec.yaml
├── pubspec.lock
└── README.md
```

*The structure may evolve as new modules are added.*

---

## Prerequisites

Before installing the project, make sure you have:

- Windows 10 or Windows 11.
- Flutter SDK.
- Dart SDK (included with Flutter).
- Python 3.11.
- Git.
- Ollama.
- A Supabase account.
- Google Chrome or an Android device for testing.

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/linguavision_ai.git
```

Navigate to the project:

```bash
cd linguavision_ai
```

### 2. Install Flutter dependencies

```bash
flutter pub get
```

### 3. Set up the Python backend

Navigate to the backend directory:

```powershell
cd backend
```

Create a virtual environment:

```powershell
py -3.11 -m venv .venv
```

Activate it:

```powershell
.\.venv\Scripts\Activate.ps1
```

Install Python dependencies:

```powershell
pip install -r requirements.txt
```

Return to the project root:

```powershell
cd ..
```

### 4. Configure Ollama

Install Ollama from:

https://ollama.com/

Download the required language model:

```powershell
ollama pull llama3.2:3b
```

Download the embedding model:

```powershell
ollama pull nomic-embed-text
```

Verify the installed models:

```powershell
ollama list
```

Make sure the Ollama service is running.

Default local API:

```text
http://localhost:11434
```

### 5. Configure Supabase

Create a project at:

https://supabase.com/

Configure the Supabase project URL and publishable key in the Flutter application.

For local development, the publishable key can be supplied through a Dart environment define.

Never commit private keys, passwords, or Supabase service-role credentials to GitHub.

---

## Configuration

### Flutter configuration

The application uses a Supabase publishable key supplied at runtime.

Example:

```powershell
flutter run -d chrome --dart-define=SUPABASE_PUBLISHABLE_KEY="YOUR_SUPABASE_PUBLISHABLE_KEY"
```

Replace the placeholder with your own project key.

### Backend configuration

The backend uses Ollama for local model inference.

Check the backend configuration before starting the server. The model name, service URLs, and other environment variables must match your local setup.

Do not commit `.env` files or credentials.

---

## Running the Application

Two services must be started during local development.

### 1. Start the FastAPI backend

Open a PowerShell terminal:

```powershell
cd C:\Users\YOUR_USER\Documents\linguavision_ai\backend
```

Activate the virtual environment:

```powershell
.\.venv\Scripts\Activate.ps1
```

Start the server:

```powershell
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Backend URL:

```text
http://localhost:8000
```

FastAPI documentation:

```text
http://localhost:8000/docs
```

### 2. Start the Flutter application

Open another PowerShell terminal:

```powershell
cd C:\Users\YOUR_USER\Documents\linguavision_ai
```

Run the application:

```powershell
flutter run -d chrome --dart-define=SUPABASE_PUBLISHABLE_KEY="YOUR_SUPABASE_PUBLISHABLE_KEY"
```

For Android testing, connect an Android device or start an emulator and use:

```powershell
flutter devices
```

Then:

```powershell
flutter run
```

---

## Database

Supabase is used for authentication and persistent user-related information.

The application includes data management for:

- User authentication.
- Learner profiles.
- Learning preferences.
- Tutor conversations.
- Tutor messages.
- Conversation history.

The database schema can evolve as additional learning features are introduced.

---

## AI Components

### Local Language Model

The application uses Ollama with:

```text
Model: llama3.2:3b
Embedding model: nomic-embed-text
```

The language model generates conversational responses and supports contextual language-learning assistance.

### OCR Processing

EasyOCR is used to detect and extract text from images.

The extracted text can then be processed by the backend for translation and learning purposes.

### Speech Generation

Edge TTS generates audio from the tutor's responses.

The application uses language-specific voices to improve the pronunciation of generated responses.

### Future Avatar Integration

Kling AI is being explored for generating natural avatar animations.

The planned integration will require a dedicated backend service to manage generation requests, video processing, and playback in Flutter.

---

## Security

Security considerations include:

- Keeping private credentials outside the Git repository.
- Using environment variables for sensitive backend configuration.
- Using Supabase Row Level Security (RLS) to protect user data.
- Validating backend requests.
- Avoiding exposure of privileged credentials in the Flutter client.
- Excluding Python virtual environments and generated build files from version control.

---

## Roadmap

| Feature | Status |
|---|---|
| Flutter application foundation | In progress / implemented |
| Supabase authentication | Implemented |
| User profile and preferences | Implemented |
| AI Tutor | Implemented |
| Local Ollama integration | Implemented |
| Tutor conversation history | Implemented |
| Speech generation | Implemented |
| Speech recognition | In progress |
| Camera translation | In progress |
| Vocabulary learning | Planned |
| Learning progress dashboard | Planned |
| AI avatar integration | Planned |
| Real-time avatar interaction | Planned |

---

## Current Development Status

LinguaVision AI is an active development project.

The current focus is improving the AI Tutor experience, multilingual speech handling, image-based translation, and the integration of a natural animated avatar.

Some features are still experimental and may change during development.

---

## Author

**Chaimaa Lahlou**

Computer Science and Network Engineering Student  
EMSI Casablanca – Morocco

Interests: Software Development, Artificial Intelligence, Mobile Applications, and Intelligent Systems.

---

## License

This project is currently developed for educational and portfolio purposes.

A formal license can be added when the project is ready for public distribution.

---

**LinguaVision AI — Learn languages through intelligent interaction.**
