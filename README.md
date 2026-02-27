# RxNova Clinical AI

**Offline Voice-Driven OPD Clinical Documentation + Decision Support System**

---

## 📌 Overview

RxNova Clinical AI is a mobile-first clinical assistant designed to support outpatient consultations by converting doctor speech into structured clinical documentation and decision support outputs.

The system captures consultation audio, transcribes speech locally, extracts structured clinical information, suggests diagnoses and investigations, and generates a complete OPD sheet including prescription — all with an offline-first architecture.

This module is intended to integrate with the broader **RxNova ecosystem** and serve as the clinical intelligence layer for outpatient workflows.

---

## 🎯 Objectives

* Reduce documentation burden during OPD consultations
* Provide real-time structured clinical note generation
* Offer AI-assisted diagnosis and investigation suggestions
* Enable voice-driven prescription creation
* Maintain patient data privacy via offline processing

---

## 🚀 Core Features

### 🗣️ Voice Consultation Capture

* Continuous microphone recording
* Real-time medical speech recognition
* Multilingual support (English + Indian languages)

### 📄 Clinical Documentation

* Chief complaints extraction
* History recording
* Examination findings
* Encounter timeline

### 🧠 Clinical Decision Support

* ICD-mapped diagnosis suggestions
* Rule-based investigation recommendations
* Drug interaction awareness (RxNova integration)

### 💊 Voice Prescription Builder

* Drug name recognition
* Dose/frequency parsing
* Structured prescription rows

### 📑 OPD Sheet Generation

* Auto-formatted consultation summary
* PDF export
* Encounter storage

### 🔐 Privacy & Offline Capability

* Local inference engines
* Encrypted SQLite storage
* Optional cloud sync

---

## 🏗️ System Architecture

### Logical Flow

```
Audio Capture → Speech Recognition → NLP Extraction
              → Structured Database → Decision Engines
              → OPD Sheet Generator → Output
```

### Physical Architecture

```
Flutter UI
   ↓
Platform Channel
   ↓
Native AI Layer (Whisper + LLM)
   ↓
SQLite + Vector Search
```

---

## 🧱 Technology Stack

### Mobile

* Flutter (UI & app logic)
* Provider (state management)

### AI Layer

* Whisper.cpp (speech recognition)
* llama.cpp (clinical extraction)
* MiniLM ONNX (embeddings)

### Storage

* SQLite
* Local vector search

### Utilities

* PDF generation
* Permission handling
* File storage

---

## 📂 Project Structure

```
rxnova_clinical_ai/

core/
  constants/
  utils/

ai/
  whisper/
  llama/
  embeddings/

data/
  db/
  repositories/
  models/

services/
  audio_service/
  extraction_service/
  diagnosis_service/
  prescription_parser/

features/
  consultation/
  patient/
  encounter/

ui/
  widgets/
  screens/
```

---

## 🗄️ Database Schema (High Level)

* PATIENT
* ENCOUNTER
* COMPLAINT
* HISTORY
* EXAM
* DIAGNOSIS
* INVESTIGATION
* PRESCRIPTION
* ICD_MASTER

---

## ⚙️ Setup Instructions

### 1. Clone repository

```
git clone <repo-url>
cd OPD_Voice_Clinicalsummary
```

> If you rename the local folder to `rxnova_clinical_ai`, update commands accordingly.

### 2. Install dependencies

```
flutter pub get
```

### 3. Add AI models

Place models in:

```
assets/models/
  whisper/
  llama/
  embeddings/
```

### 4. Run app

```
flutter run
```

---

## 🧪 Development Roadmap

### Phase 1

* Audio capture
* Whisper transcription
* Structured note generation

### Phase 2

* Diagnosis engine
* Investigation rules
* Voice prescription

### Phase 3

* SOAP summarization
* Learning templates
* Multilingual optimization

---

## 📊 Evaluation Strategy

* Curated OPD transcript dataset
* Manual gold annotations
* Precision / recall metrics
* Clinical usability testing

---

## 🔮 Future Enhancements

* Insurance coding support
* Quality audit analytics
* Population health insights
* Hospital deployment mode
* Research dataset export

---

## 🤝 Contribution Guidelines

* Use modular architecture
* Maintain offline-first compatibility
* Add unit tests for services
* Follow repository pattern for data layer

---

## 📜 License

Internal development build — licensing to be defined.

---

## 👨‍⚕️ Intended Users

* Outpatient physicians
* Clinic networks
* Rural healthcare providers
* Digital health platforms

---

## ⭐ Vision

To build an AI-assisted outpatient operating system that enables clinicians to document faster, decide smarter, and deliver higher quality care without compromising workflow efficiency or patient privacy.

---
