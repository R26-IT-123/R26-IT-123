# ANIE – System Architecture

## 1. Introduction

The Academic Note Intelligence Engine (ANIE) is a component of the ShareMate application designed to support academic note processing, content analysis, and quality assessment.

## 2. Project Structure

The ANIE backend is organized into separate modules to improve maintainability and support future development.

### Routers
The `routers` directory contains API route definitions for note-related and topic-related operations.

### Schemas
The `schemas` directory contains data structures used for request and response validation.

### Services
The `services` directory contains the business logic for academic note processing.

The current project includes modules such as:

- `auth.py` – Authentication-related functions.
- `extractor.py` – Document text extraction.
- `firebase.py` – Firebase integration.
- `note_service.py` – Note processing services.
- `scorer.py` – Academic note scoring operations.

### Utilities
The `utils` directory contains supporting functions, including token-related utilities.

## 3. Note Processing Workflow

The ANIE component is designed around the following general workflow:

1. Receive an academic note through the application.
2. Process the uploaded academic material.
3. Extract text from the document.
4. Analyze the academic content.
5. Evaluate relevant quality indicators.
6. Generate assessment results for the application.

## 4. Model Resources

The ShareMate repository contains a `model` directory with resources related to semantic analysis and topic processing, including FAISS index data, embeddings, and topic metadata.

## 5. Technologies

The component uses Python-based backend services and includes modules for API handling, document processing, and academic content analysis.

## 6. Maintainability

Separating routers, schemas, services, and utilities helps organize the project and allows individual components to be maintained and tested independently.