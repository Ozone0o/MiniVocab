# MiniVocab Architecture

## Overview

MiniVocab is a minimalist macOS floating word-card app built with SwiftUI + AppKit (NSPanel).
It stays always-on-top, never steals focus, and provides spaced-repetition word learning
with offline-first, local-only data storage using Core Data.

## Core Principles

1. **Minimal UI** — Only word + settings gear on the floating window.
2. **Two-state cards** — Question State (word + example) → Answer State (definition + ratings).
3. **Focus discipline** — Window never steals focus; only reacts when clicked.
4. **Decoupled layers** — Scheduler, Importers, UI, and Persistence are independent modules.
5. **Offline-first** — All data stored locally; no network calls.

## Module Structure

```
MiniVocab/
├── App/
│   └── MiniVocabApp.swift          # SwiftUI App entry, window & settings setup
├── Models/
│   ├── Word.swift                  # Word entity (SwiftData/Core Data model)
│   ├── WordBook.swift              # WordBook entity
│   ├── ReviewRecord.swift          # ReviewRecord entity
│   └── LearningState.swift         # LearningState entity
├── Persistence/
│   └── PersistenceController.swift # Core Data stack / SwiftData container
├── Scheduler/
│   ├── ReviewScheduler.swift       # Scheduler protocol
│   └── SimpleSpacedRepetitionScheduler.swift # First-implement scheduler
├── Importers/
│   ├── WordBookImporter.swift      # Importer protocol
│   ├── CSVImporter.swift
│   ├── TSVImporter.swift
│   ├── TXTImporter.swift
│   └── JSONImporter.swift
├── Services/
│   ├── StudySessionManager.swift   # Session logic: picks next word
│   └── WordBookService.swift       # CRUD for word books
├── Window/
│   └── FloatingWindowController.swift  # FocusManager + NSPanel lifecycle
├── ViewModels/
│   └── FloatingWordViewModel.swift   # State machine: Question ↔ Answer
└── Views/
    ├── FloatingWordView.swift      # Main floating card UI
    ├── SettingsView.swift          # Settings window content
    ├── WordBookSettingsView.swift  # Word book management
    └── ImportPreviewView.swift     # Field mapping + import preview
```

## Data Flow

```
Core Data (Models)
    ↑↓
PersistenceController
    ↑↓
StudySessionManager ←→ ReviewScheduler
    ↑↓
FloatingWordViewModel
    ↑↓
FloatingWordView
```

## Focus Model

```
Idle (not focused)
    ← user clicks panel →
Interactive
    ← user rates word →
Restore previous app
```

## Scheduler Protocol

```swift
protocol ReviewScheduler {
    func nextReviewInterval(for state: LearningState, rating: Rating) -> Int
    func difficultyModifier(for state: LearningState) -> Double
}
```

## Importer Protocol

```swift
protocol WordBookImporter {
    func canImport(fileURL: URL) -> Bool
    func importWords(fileURL: URL) throws -> [Word]
}
```
