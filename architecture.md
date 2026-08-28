# MiniVocab Architecture

## Overview

MiniVocab is a macOS floating vocabulary card built with SwiftUI, AppKit, and SwiftData. The application is offline-first: vocabulary books, learning progress, review records, and preferences are kept locally on the user's Mac.

The existing product flow is:

```text
Import a local vocabulary file
    → create and manage a vocabulary book
    → select a book and start learning
    → show a word, example, meaning, and pronunciation
    → record a rating
    → schedule the next review
    → persist progress locally
    → restore the active book on the next launch
```

This document describes the current implementation. It is not a proposal for changing the learning experience.

## Module Structure

```text
MiniVocab/
├── App/
│   └── MiniVocabApp.swift                 # SwiftUI App entry and WindowGroup
├── Models/
│   ├── Word.swift                          # SwiftData Word model
│   ├── WordBook.swift                      # SwiftData WordBook model
│   ├── ReviewRecord.swift                  # SwiftData review history model
│   ├── LearningState.swift                 # SwiftData per-word learning state
│   └── AppSettings.swift                   # UserDefaults-backed SettingsStore
├── Persistence/
│   └── PersistenceController.swift         # SwiftData ModelContainer and queries
├── Importers/
│   ├── WordBookImporter.swift              # Importer protocol and ImportedWord
│   ├── CSVImporter.swift                   # CSV parser and column detection
│   ├── TSVImporter.swift                   # Tab-separated importer
│   ├── TXTImporter.swift                   # Line-based text importer
│   └── JSONImporter.swift                  # JSON array importer
├── Scheduler/
│   ├── ReviewScheduler.swift               # Rating and scheduler protocol
│   └── SimpleSpacedRepetitionScheduler.swift
├── Services/
│   ├── StudySessionManager.swift            # Round/group session state
│   ├── WordBookService.swift                # Word-book CRUD, import, and export
│   └── ExampleDatabase.swift                # Bundled SQLite example lookup
├── Window/
│   └── FloatingWindowController.swift       # NSWindow configuration and focus
├── ViewModels/
│   └── FloatingWordViewModel.swift          # Question/answer state machine
└── Views/
    ├── FloatingWordView.swift               # Main floating card
    └── SettingsView.swift                  # Appearance, books, and data settings
```

## Application and Window Lifecycle

- `MiniVocabApp` creates the main `WindowGroup`, the shared `SettingsStore`, the persistence controller, the scheduler, and the study session manager.
- `WindowAccessor` obtains the `NSWindow` created by SwiftUI.
- `FloatingWindowConfigurator` applies the existing title-bar, resize, movement, opacity, and always-on-top settings to that `NSWindow`.
- `FocusManager` records the previous frontmost application during interaction and restores it after a rating.
- The settings screen is presented from the floating window as a sheet. Escape dismisses it.

## Data and Persistence

`PersistenceController` creates one SwiftData `ModelContainer` for the four existing models:

```text
Word
WordBook → words
LearningState → wordId
ReviewRecord → wordId
```

The production container is not in-memory and has no repository-relative store URL, so SwiftData manages the database in the normal macOS application data location. The source tree does not contain or generate the runtime database.

`SettingsStore` persists appearance, window, study-order, session-size, and selected-book settings through `UserDefaults`. No SwiftData schema or persistence semantics are changed by the repository cleanup.

## Importers

`WordBookImporter` exposes `canImport(fileURL:)` and `importWords(fileURL:)`. `WordBookService` selects the first compatible importer and creates the `WordBook` and associated `Word` objects.

Supported formats and current behavior:

- **CSV** — header-based comma-delimited input. The parser handles quoted fields, commas inside quotes, escaped quotes (two consecutive quotes), UTF-8 BOM, empty fields, CRLF/LF line endings, and quoted line breaks. Incomplete rows are skipped using the existing best-effort import behavior.
- **TSV** — header-based tab-delimited input.
- **TXT** — one word and meaning per line, with space, tab, or pipe separators; phonetic prefixes such as `/ipa/` are supported.
- **JSON** — an array of objects with the existing flexible word, meaning, phonetic, example, and translation field names.

Importer parsing does not change the import button, file picker, supported extensions, `WordBook` model, or study flow.

## Study Session and Scheduler

`StudySessionManager` keeps the existing session state in memory and coordinates it with persistence:

- New words are presented in rounds according to the configured words-per-round value.
- Groups contain the configured number of rounds.
- Sequential and random order use the existing settings.
- Overdue long-term reviews are considered before another new round.
- Weak words are re-queued and may enter group review.
- Ratings are passed to `SimpleSpacedRepetitionScheduler`, which updates `LearningState` and creates a `ReviewRecord`.

`FloatingWordViewModel` presents the question state, reveals the answer state, records the selected rating, and loads the next word.

## Bundled Resource

`MiniVocab/Resources/examples.sqlite` is a required read-only application resource. `ExampleDatabase` verifies the `examples(word, sentence)` table and looks up an example when a word does not already have one. It is separate from SwiftData and from user vocabulary books.

The repository does not claim authorship or licensing for the sentence corpus. Its provenance and redistribution terms must be confirmed before a public release.

## Repository and User Data Boundary

```text
Repository
├── source code
├── tests
├── documentation
└── required application resources (examples.sqlite)

User's Mac
├── imported vocabulary books (CSV / TSV / TXT / JSON)
├── SwiftData learning database
├── UserDefaults preferences
└── exported learning data
```

Personal vocabulary, learning history, runtime databases, preferences, exports, build products, and debug symbols do not belong in the Git repository.
