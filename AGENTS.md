# AGENTS.md — Where's My Space

Where's My Space is a SwiftUI macOS app that shows what is using disk space, with a storage bar and a browsable file and folder list. The Xcode project is maintained in Xcode (no XcodeGen).

## Commands

- `make` (`make setup dev`): check the toolchain, then build Debug and open it.
- Unit tests: `xcodebuild test -project WheresMySpace.xcodeproj -scheme WheresMySpace -destination 'platform=macOS,arch=arm64'`. Keep `arch=arm64`: without it xcodebuild matches two destinations and the test runner can hang.
- `make build`: Release build. `make open`: Release build, then open it.
- `make install` / `make uninstall` / `make reinstall`: manage `/Applications`.
- `make close` / `make clean`; `make help` lists everything.

## Layout

- `WheresMySpace/StorageViewModel.swift`: scans the disk and builds the tree.
- `WheresMySpace/FileItem.swift`, `FolderItem.swift`: models.
- `WheresMySpace/ContentView.swift`, `FileListView.swift`, `StorageBarView.swift`: UI.
- `WheresMySpaceTests/`: XCTest suite.

## Conventions

- New source files must be added to `WheresMySpace.xcodeproj` (the project doesn't use synchronized folders).
- Scanning must stay off the main thread and tolerate permission errors.
- Deleting moves items to the Trash (`moveToTrash`); never remove files permanently.

## Design principles

Follow the [design principles](docs/rules/design-principles.md) for any UI work.

## After changing code

1. Run the unit tests (command above).
2. Run `make dev` to build and open the app.
3. Commit with a short, one-line message. Don't wait for approval in this project (this overrides the global approval rule). `.claude/hooks/test-build-commit.sh` does all three automatically after each turn.
