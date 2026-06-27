# ShortClip

ShortClip is a lightweight macOS menu bar clipboard helper for text snippets and short-lived clipboard history.

## Features

- Keeps recent clipboard text available from the menu bar without persisting clipboard history to disk.
- Stores up to 20 clipboard history entries and expires them after one hour.
- Lets you pause clipboard capture and recall actions from the menu bar or Settings.
- Lets you add, edit, delete, and recall reusable text snippets.
- Persists snippets in Application Support and encrypts them at rest with AES-GCM.
- Stores the snippet encryption key in the macOS Keychain with a user-presence access policy.
- Keeps encrypted snippet files intact when Keychain access fails, and disables snippet edits until unlock succeeds.
- Migrates older plaintext snippet files into encrypted storage when they are found.
- Opens a quick-paste panel with `Cmd + Shift + V` by default.
- Lets you customize the quick-paste shortcut in Settings.
- Supports keyboard navigation in the quick-paste panel, including arrow keys, row numbers, details, Return, and Escape.
- Copies selected items back to the clipboard, with optional automatic paste when Accessibility permission is granted.
- Lets you disable automatic paste so quick-paste always behaves as copy-only.
- Supports launch-at-login through the macOS login item API.
- Provides English and Japanese UI text.
- Writes bounded diagnostic logs for startup, settings, persistence, and Keychain flow diagnostics.

## Requirements

- macOS 14 or later.
- Swift 6 toolchain with Swift Package Manager.
- Accessibility permission is optional and is only required for automatic paste.

## Run

```bash
swift run ShortClipApp
```

The app appears in the macOS menu bar. Open the menu bar window to preview recent snippets and clipboard history, open the library window, change settings, and manage snippets.

Press `Cmd + Shift + V` anywhere to open the quick-paste panel. Selecting an item always copies it to the clipboard. If Accessibility permission is granted and automatic paste is enabled, ShortClip restores focus to the previous app and sends `Cmd + V`.

If Accessibility permission is not granted, ShortClip does not prompt automatically during quick-paste. Use the `Enable Accessibility` button in Settings or the menu bar window when you want to allow automatic paste.

## Test

```bash
swift test
```

If Command Line Tools cannot resolve `import Testing`, pass the framework search path explicitly:

```bash
swift test -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks
```

## Build A Local `.app`

```bash
zsh ./Scripts/build-app.sh
```

This creates `dist/ShortClip.app`.

The local build script ad hoc signs the bundle. Use Developer ID signing, Hardened Runtime, and notarization before distributing a downloadable release outside your own machine.

## Privacy And Security

- ShortClip has no external Swift package dependencies.
- The app does not contain network code and does not send clipboard or snippet data anywhere.
- Clipboard monitoring is limited to plain text from `NSPasteboard.general`.
- Clipboard history is kept in memory only and is cleared when the app exits.
- Blank clipboard values are ignored.
- Snippets are stored at `~/Library/Application Support/ShortClip/snippets.json`.
- The snippet backup file is stored next to it as `snippets.backup.json`.
- Snippet files are encrypted before being written to disk.
- The encryption key is stored in Keychain service `dev.shortclip.snippet-encryption`, account `snippet-encryption-key-v2`.
- New Keychain items use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and `.userPresence`.
- The resolved encryption key is cached in process memory for the current app session to reduce repeated Keychain prompts.
- Diagnostic logs are written to `~/Library/Application Support/ShortClip/Logs/shortclip.log`.
- Diagnostic logs record counts, paths, status values, and error summaries, but not snippet text or clipboard history text.
- The diagnostic log file is reset after it reaches 256 KiB.
- Automatic paste uses a synthetic `Cmd + V` event and requires macOS Accessibility trust.
- Launch-at-login is managed by `SMAppService.mainApp`, so macOS owns the final login item state and approval flow.

## Data Locations

| Purpose | Location |
| --- | --- |
| Snippet storage | `~/Library/Application Support/ShortClip/snippets.json` |
| Snippet backup | `~/Library/Application Support/ShortClip/snippets.backup.json` |
| Diagnostic log | `~/Library/Application Support/ShortClip/Logs/shortclip.log` |
| Settings domain | `dev.shortclip.settings` |
| Keychain service | `dev.shortclip.snippet-encryption` |

## Repository Hygiene

Generated build output and local tooling state should not be committed. The root `.gitignore` excludes `.build/`, `dist/`, `.DS_Store`, SwiftPM local state, Xcode user state, and local `.codex/` agent configuration.

Before publishing or tagging a release, verify:

```bash
swift test
zsh ./Scripts/build-app.sh
```

## License

No license file is included yet. Add a license before accepting external reuse or contributions.
