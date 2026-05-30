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
renders Markdown through SwiftUI/AppKit, shows a visible `Copy` button for each
fenced Markdown code block, and provides table copy controls for Markdown, CSV,
and TSV.

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
- `App/` - host app with status, repository, and maintenance actions.
- `PreviewExtension/` - Quick Look preview extension UI.
- `Core/MarkdownBlockParser.swift` - fenced-code-aware Markdown block parser.
- `Core/MarkdownTableExporter.swift` - Markdown/CSV/TSV table export.
- `Core/MarkdownOutlineBuilder.swift` - document outline extraction.
- `Core/MarkdownPlainText.swift` - shared inline Markdown cleanup for exports.
- `Tests/` - parser, table export, and outline tests.
- `.github/workflows/ci.yml` - GitHub Actions build/test workflow.
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
  rules, inline Markdown text, GFM-style tables, document outlines, and code
  blocks are rendered without WebKit;
- code detection covers backtick fences, tilde fences, indented code blocks, and
  exported language-label blocks such as `JSON` / `Ini, TOML`;
- each fenced code block gets a visible green `Copy` button;
- each table gets visible `MD`, `CSV`, and `TSV` copy buttons;
- copy writes directly to `NSPasteboard.general`;
- the extension reads UTF-8, Windows CP1251, and ISO Latin 1 text as fallbacks.
- the host app window now exposes install status, GitHub access, and maintenance
  commands.

This is intentionally a preview extension, not a Markdown editor.

## Verification

Build and tests:

- `xcodegen generate --spec project.yml --project .` completed successfully.
- `xcodebuild test -project MDQuickCopy.xcodeproj -scheme MDQuickCopyCoreTests -destination 'platform=macOS'` passed.
- Result after the v1.2.0 Core update: 13 tests, 0 failures.
- `./script/build_and_run.sh --verify` built the Release app and confirmed the
  host app launches.

Install and registration:

- `./script/install_app.sh` installed `/Applications/MD Quick Copy.app`.
- Installed app version: `1.2.0`, build `3`.
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

v1.2.0 Finder flow on the user's larger report file:

- Opened `/Users/AlexFisenkov_1/Downloads/VPN через CDN_ Альтернативы Cloudflare в РФ.md` in Finder.
- Pressed Space to invoke Quick Look.
- Confirmed a rendered document outline at the top of the Quick Look preview.
- Confirmed the large Markdown tables render as native table UI, not raw Markdown.
- Confirmed visible table copy controls: `MD`, `CSV`, and `TSV`.
- Clicked `MD`, `CSV`, and `TSV` in the live Quick Look preview and verified the
  expected clipboard payloads with `pbpaste`; repeated after reinstalling the
  final build.
- Evidence screenshots:
  - `test-output/screenshots/vpn-cdn-finder-v120.png`
  - `test-output/screenshots/vpn-cdn-table-buttons-v120.png`

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
