# MiniVocab

MiniVocab is a lightweight macOS vocabulary learning app designed to stay unobtrusively on your desktop while you work or study.

## Features

- Lightweight floating vocabulary window
- Custom vocabulary books
- CSV / TSV / TXT / JSON import
- Local vocabulary storage
- Review scheduling
- Example sentences
- Pronunciation
- Persistent learning progress
- Adjustable font size and transparency
- Always-on-top mode
- Offline-first design

## Screenshots

Screenshots can be added here.

## Requirements

- macOS 14 or later
- Swift 6.0 or later
- Xcode 16 or later (when building through Xcode)

## Build

MiniVocab is distributed as a Swift Package. From the repository root:

```bash
swift build
```

You can also open `Package.swift` in Xcode and build the `MiniVocab` scheme.

## Tests

```bash
swift test
```

## Vocabulary Import

MiniVocab supports user-provided vocabulary books in:

- CSV with a header row
- TSV with a header row
- TXT lines containing a word and meaning
- JSON arrays of vocabulary objects

CSV import supports quoted fields, commas inside quoted fields, escaped quotes, UTF-8 BOM, empty fields, and CRLF line endings.

## Repository and User Data

The repository contains the application source, tests, documentation, and required application resources. Imported vocabulary books and learning data remain on the user's Mac:

```text
Repository
├── source code
├── tests
├── documentation
└── required application resources

User's Mac
├── imported vocabulary books
├── learning progress
├── preferences
└── generated / exported user data
```

Personal learning data is not part of the GitHub repository. Users provide their own CSV, TSV, TXT, or JSON files through MiniVocab.

## Privacy

- Vocabulary books stay on the user's Mac.
- Learning progress is stored locally by SwiftData.
- Preferences are stored locally using UserDefaults.
- MiniVocab does not require a cloud account or network access.

## Example Sentences

The bundled `examples.sqlite` resource contains example sentences used to enrich vocabulary cards when an imported word does not already have an example. It is application data, not a user vocabulary book. Confirm the database's source, license, and required attribution before redistributing a public release; this project makes no claim that the sentence data is original.

## Releases

Release `.dmg` files belong in [GitHub Releases](https://github.com/Ozone0o/MiniVocab/releases). The source tree does not track compiled `.app`, `.dmg`, or debug-symbol files.

## License

Apache-2.0. See [LICENSE](LICENSE).
