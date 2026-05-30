# Markdown Quick Look setup report

Date: 2026-05-30

## Task understanding

The requested result was a proper macOS Quick Look setup for `.md` files:

- Markdown should open in Finder Quick Look as rendered content, not raw text.
- Fenced code/copyable fields should have visible copy controls.
- The solution should be installed as a normal app under `/Applications`.
- It should be registered with macOS Quick Look/LaunchServices so it survives normal restarts.

## Current installed solution

Active app:

- `/Applications/MD Quick Copy.app`
- app bundle id: `com.alexfisenkov.MDQuickCopy`
- Quick Look extension id: `com.alexfisenkov.MDQuickCopy.PreviewExtension`
- extension path: `/Applications/MD Quick Copy.app/Contents/PlugIns/MD Quick Copy Preview Extension.appex`

The app is a native macOS app with a Quick Look preview extension. The extension
renders Markdown through SwiftUI/AppKit and shows a visible `Copy` button for each
fenced Markdown code block.

`QLMarkdown.app` was also installed during the first pass:

- `/Applications/QLMarkdown.app`
- extension id: `org.sbarex.QLMarkdown.QLExtension`

It is intentionally left installed but disabled through `pluginkit` so Finder uses
`MD Quick Copy` for Markdown previews.

## Project structure

- `README.md` - public project overview, installation, update, uninstall, and
  development instructions.
- `LICENSE` - MIT license.
- `.gitignore` - excludes local build products, verification screenshots, and
  machine-specific files.
- `project.yml` - XcodeGen project definition.
- `App/` - thin host app.
- `PreviewExtension/` - Quick Look preview extension UI.
- `Core/MarkdownBlockParser.swift` - fenced-code-aware Markdown block parser.
- `Tests/MarkdownBlockParserTests.swift` - parser tests.
- `script/build_and_run.sh` - project-local build/run entrypoint.
- `script/install_app.sh` - Release build, `/Applications` install, LaunchServices
  registration, pluginkit registration, Quick Look cache reset.
- `.codex/environments/environment.toml` - Codex Run action wiring.

## Implementation notes

The first custom implementation used `WKWebView`, `marked`, and `highlight.js`,
but real Quick Look rendering crashed the WebKit content process on this Mac.
That path was removed.

The final implementation is native SwiftUI/AppKit inside the Quick Look extension:

- headings, paragraphs, ordered/unordered/task lists, blockquotes, horizontal
  rules, inline Markdown text, GFM-style tables, and code blocks are rendered
  without WebKit;
- code detection covers backtick fences, tilde fences, indented code blocks, and
  exported language-label blocks such as `JSON` / `Ini, TOML`;
- each fenced code block gets a visible green `Copy` button;
- copy writes directly to `NSPasteboard.general`;
- the extension reads UTF-8, Windows CP1251, and ISO Latin 1 text as fallbacks.

This is intentionally a preview extension, not a Markdown editor.

## Verification

Build and tests:

- `xcodegen generate --spec project.yml --project .` completed successfully.
- `xcodebuild test -project MDQuickCopy.xcodeproj -scheme MDQuickCopyCoreTests -destination 'platform=macOS'` passed.
- Result after the expanded Markdown renderer update: 7 tests, 0 failures.

Install and registration:

- `./script/install_app.sh` installed `/Applications/MD Quick Copy.app`.
- `codesign --verify --deep --strict --verbose=2 '/Applications/MD Quick Copy.app'` passed.
- App entitlements contain sandboxing only.
- Extension entitlements contain sandboxing and user-selected read-only file access.
- `pluginkit` shows one active `com.alexfisenkov.MDQuickCopy.PreviewExtension`
  from `/Applications`.
- `pluginkit` shows `org.sbarex.QLMarkdown.QLExtension` as ignored.

Real Finder flow:

- Opened `test-fixtures/interactive-copy.md` in Finder.
- Pressed Space to invoke Quick Look.
- Confirmed rendered Markdown preview with visible `Copy` buttons.
- Evidence screenshot: `test-output/screenshots/md-quick-copy-native.png`.
- Manual user check confirmed the copy button copied text and the copied text
  pasted successfully.
- `pbpaste` after the manual check returned:

```swift
let value = "second block"
print(value)
```

## Limitations and risks

- The app is Developer ID signed locally but not notarized. `spctl` reports
  `source=Unnotarized Developer ID`. It works on this Mac after local
  installation/registration, but distributing it to other Macs should include
  Apple notarization.
- The public build defaults to local/ad-hoc signing if no Developer ID
  certificate is available. `script/build_and_run.sh` can use a Developer ID
  certificate automatically or through explicit environment variables.
- A physical reboot was not performed. Persistence is based on normal macOS
  app placement in `/Applications`, LaunchServices registration, pluginkit user
  election, and Quick Look cache reset.
- The renderer intentionally does not execute embedded HTML or remote content
  from Markdown files. Very advanced Markdown extensions outside common
  CommonMark/GFM reading patterns may need future parsing work.

## Reinstall/update command

From this project directory:

```bash
./script/install_app.sh
```
