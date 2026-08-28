# MiniVocab

English | [简体中文](README.zh-CN.md)

A small macOS vocabulary card designed to live beside whatever you're already doing.

Instead of opening a vocabulary app whenever you want to study, keep MiniVocab near your work. Glance at a word while code is compiling, a page is loading, or a task is between steps; recall what you can, then continue.

<p align="center">
  <a href="https://github.com/Ozone0o/MiniVocab/releases/latest"><strong>Download for macOS</strong></a>
</p>

<p align="center">
  <img src="docs/hero.png" width="900" alt="MiniVocab floating beside a desktop workspace">
</p>

## Learn without leaving what you're doing

MiniVocab is meant to stay at the edge of your desktop while you write code, read a paper, browse the web, or work. It does not ask you to switch into a separate study mode. A short pause is enough for one card.

## See it, recall it, move on

<p align="center">
  <img src="docs/review-demo.gif" width="720" alt="MiniVocab review demo">
</p>

The loop is deliberately short: see the word, think for a moment, reveal the answer, rate it, and move on.

## A deliberately small learning loop

The first state shows the word and an example sentence when one is available. Revealing the card shows the phonetic spelling, meaning, and the four review choices used by the current interface: `忘记`, `模糊`, `认识`, and `熟知`.

<p align="center">
  <img src="docs/study-flow.png" width="1000" alt="MiniVocab question and answer states">
</p>

Review records and per-word learning state are saved locally. The next session continues from the local data instead of starting over.

## Bring your own vocabulary

MiniVocab does not require a fixed word list. Import the vocabulary you already use, then choose a book and start learning.

Supported formats:

- CSV
- TSV
- TXT
- JSON

CSV and TSV files use a header row. TXT files can contain a word and meaning separated by spaces, tabs, or pipes. JSON files use an array of vocabulary objects. CSV import also handles quoted fields, commas inside quotes, escaped quotes, UTF-8 BOM, empty fields, and CRLF line endings.

A small example:

```csv
word,meaning,example
serendipity,an unexpected good discovery,I found the book by serendipity.
resilient,able to recover,She remained resilient after the setback.
```

Imported books are local user data; they are not part of this repository.

## Make it fit your desktop

<p align="center">
  <img src="docs/settings.png" width="1000" alt="MiniVocab settings and vocabulary book management">
</p>

The settings sheet lets you adjust the app around your workspace:

- font size and window opacity
- always-on-top behavior
- sequential or shuffled word order
- words per round and rounds per group
- vocabulary book selection, import, deletion, and start learning
- learning-data export and learning-record reset

## Local-first

No account is required. Vocabulary books and learning progress stay on your Mac. SwiftData stores the local vocabulary and review state, while UserDefaults stores appearance and study settings. Learning data can be exported as JSON from the Data settings.

The bundled `examples.sqlite` is a read-only application resource used to look up example sentences when an imported word does not already have one. Its data provenance and redistribution terms should be verified before distributing a packaged release.

## Build from source

MiniVocab is a Swift Package with a native macOS executable target. The repository currently contains source code rather than a packaged `.app` or `.dmg`.

Requirements:

- macOS 14 or later
- Swift 6.0 toolchain
- Xcode 16 or later when building through Xcode

Clone the repository and run:

```bash
git clone https://github.com/Ozone0o/MiniVocab.git
cd MiniVocab
swift build
swift test
```

You can also open `Package.swift` in Xcode and build the `MiniVocab` scheme. Packaged builds belong in [GitHub Releases](https://github.com/Ozone0o/MiniVocab/releases), not in the source tree.

## Under the hood

MiniVocab uses Swift, SwiftUI, AppKit, and SwiftData with no external package dependencies. The main window is a native `WindowGroup` window configured for floating, resizing, movement, opacity, and always-on-top behavior.

For the implementation map, see [architecture.md](architecture.md).

## Repository and user data

| Repository | Your Mac |
| --- | --- |
| Source code, tests, docs, and required resources | Imported vocabulary books |
| `examples.sqlite` application resource | SwiftData learning progress |
|  | UserDefaults preferences and exported data |

Personal vocabulary books, learning history, runtime databases, preferences, and exports should stay outside the GitHub repository.

## License

MiniVocab is licensed under the [Apache License 2.0](LICENSE).
