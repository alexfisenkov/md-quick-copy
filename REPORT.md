# Markdown Quick Look setup report

Date: 2026-05-30

## Task understanding

The requested result is a proper macOS Quick Look setup for `.md` files:

- Markdown opens in Finder Quick Look as rendered content, not raw text.
- Fenced code and exported code-like blocks have visible copy controls.
- Markdown tables render as tables and have copy controls.
- Rendered text can be partially selected with the mouse and copied.
- Markdown links and bare URLs are visible and clickable.
- The solution is installed as a normal app under `/Applications`.
- The project is public, documented, tested, and reproducible from GitHub.

## Current installed solution

Active app:

- `/Applications/MD Quick Copy.app`
- version: `1.3.0`, build `4`
- app bundle id: `com.alexfisenkov.MDQuickCopy`
- Quick Look extension id: `com.alexfisenkov.MDQuickCopy.PreviewExtension`
- extension path: `/Applications/MD Quick Copy.app/Contents/PlugIns/MD Quick Copy Preview Extension.appex`

The app is a native macOS app with a Quick Look preview extension. The extension
renders Markdown through SwiftUI/AppKit, shows a visible `Copy` button for each
fenced Markdown code block, provides table copy controls for Markdown, CSV, and
TSV, renders text through a selectable native `NSTextView`, and opens/copies
links through the Quick Look extension context.

`QLMarkdown.app` is intentionally left installed but disabled through
`pluginkit` so Finder uses `MD Quick Copy` for Markdown previews:

- `/Applications/QLMarkdown.app`
- ignored extension id: `org.sbarex.QLMarkdown.QLExtension`

## Project structure

- `README.md` - public project overview, installation, update, uninstall, and
  development instructions.
- `CHANGELOG.md` - release history.
- `REPORT.md` - local engineering report and verification trace.
- `LICENSE` - MIT license.
- `.gitignore` - excludes local build products, verification screenshots, and
  machine-specific files.
- `project.yml` - XcodeGen project definition.
- `App/` - host app with status, repository, and maintenance actions.
- `PreviewExtension/PreviewViewController.swift` - Quick Look entrypoint and
  top-level preview composition.
- `PreviewExtension/MarkdownPreviewAttributedTextRenderer.swift` - native
  attributed renderer for selectable Markdown text blocks.
- `PreviewExtension/SelectableAttributedTextView.swift` - AppKit text view bridge
  for text selection, partial-copy state, and link hit-testing.
- `PreviewExtension/` - remaining Quick Look preview UI.
- `Core/MarkdownBlockParser.swift` - fenced-code-aware Markdown block parser.
- `Core/MarkdownTableExporter.swift` - Markdown/CSV/TSV table export.
- `Core/MarkdownOutlineBuilder.swift` - document outline extraction.
- `Core/MarkdownPlainText.swift` - shared inline Markdown cleanup for exports.
- `Core/MarkdownAttributedStringBuilder.swift` - inline Markdown parsing that
  preserves whitespace and exposes link attributes.
- `Tests/` - parser, table export, outline, and attributed Markdown tests.
- `test-fixtures/selection-links.md` - runtime fixture for selection and links.
- `.github/workflows/ci.yml` - GitHub Actions build/test workflow.
- `script/build_and_run.sh` - project-local build/run entrypoint.
- `script/install_app.sh` - Release build, `/Applications` install,
  LaunchServices registration, pluginkit registration, and Quick Look cache
  reset.
- `.codex/environments/environment.toml` - Codex Run action wiring.

## Implementation notes

The first custom implementation used `WKWebView`, `marked`, and `highlight.js`,
but real Quick Look rendering crashed the WebKit content process on this Mac.
That path was removed.

The current implementation is native SwiftUI/AppKit inside the Quick Look
extension:

- headings, paragraphs, ordered/unordered/task lists, blockquotes, horizontal
  rules, inline Markdown text, GFM-style tables, document outlines, and code
  blocks are rendered without WebKit;
- text blocks use an `NSTextView` bridge, so rendered text can be selected with
  the mouse;
- selecting rendered text shows a visible `Copy selection` button inside the
  preview;
- Markdown links and bare URLs are parsed into native link attributes;
- link hit-testing is limited to the actual rendered link bounds to avoid opening
  a URL from nearby empty space;
- if Quick Look refuses to open a URL, the URL is copied to the clipboard;
- code detection covers backtick fences, tilde fences, indented code blocks, and
  exported language-label blocks such as `JSON` / `Ini, TOML`;
- each fenced/code-like block gets a visible green `Copy` button;
- each table gets visible `MD`, `CSV`, and `TSV` copy buttons;
- copy writes directly to `NSPasteboard.general`;
- the extension reads UTF-8, Windows CP1251, and ISO Latin 1 text as fallbacks;
- the host app window exposes install status, GitHub access, and maintenance
  commands.

This is intentionally a preview extension, not a Markdown editor. Quick Look does
not consistently grant preview extensions normal first-responder ownership, so
partial text copying is exposed through the visible `Copy selection` button
instead of relying on Command-C.

## Verification

Build and tests:

- `xcodebuild test -project MDQuickCopy.xcodeproj -scheme MDQuickCopyCoreTests -destination 'platform=macOS'` passed.
- Result after the v1.3.0 update: 16 tests, 0 failures.
- `./script/build_and_run.sh --build-only` built the Release app successfully.

Install and registration:

- `./script/install_app.sh` installed `/Applications/MD Quick Copy.app`.
- Installed app version: `1.3.0`, build `4`.
- `codesign --verify --deep --strict --verbose=2 '/Applications/MD Quick Copy.app'` passed.
- `pluginkit -m -p com.apple.quicklook.preview` shows active
  `com.alexfisenkov.MDQuickCopy.PreviewExtension(1.3.0)`.
- `pluginkit -m -p com.apple.quicklook.preview` shows ignored
  `org.sbarex.QLMarkdown.QLExtension(1.5.1)`.

Runtime selection and links:

- Opened `test-fixtures/selection-links.md` in Finder Quick Look.
- Selected part of a rendered paragraph with the mouse.
- Clicked `Copy selection`.
- `pbpaste` returned exactly:

```text
he selectable target phrase for partial mouse cop
```

- Clicked the rendered Markdown link `Example Domain`; clipboard fallback stored
  `https://example.com/`.
- Clicked the rendered bare URL; clipboard fallback stored
  `https://example.com/path?q=quick-look`.
- Evidence screenshots:
  - `test-output/screenshots/selection-links-v130-final-reverify-open2.png`
  - `test-output/screenshots/selection-links-v130-final-reverify-selected.png`
  - `test-output/screenshots/selection-links-v130-final-reverify-copied.png`

Runtime on the user's larger report file:

- Opened `/Users/AlexFisenkov_1/Downloads/VPN через CDN_ Альтернативы Cloudflare в РФ.md` in Finder Quick Look.
- Confirmed rendered document outline and headings.
- Confirmed large Markdown tables render as native table UI, not raw Markdown.
- Confirmed visible table copy controls: `MD`, `CSV`, and `TSV`.
- Clicked `MD` on the live table; `pbpaste` returned the Markdown table payload.
- Confirmed exported code-like `Ini, TOML` block renders as a code panel with a
  visible `Copy` button.
- Clicked `Copy` on that code panel; `pbpaste` returned the sysctl configuration
  text.
- Confirmed the source list renders bare URLs as blue clickable links.
- Evidence screenshots:
  - `test-output/screenshots/vpn-cdn-v130-final-reverify-top.png`
  - `test-output/screenshots/vpn-cdn-v130-final-reverify-table.png`
  - `test-output/screenshots/vpn-cdn-v130-final-reverify-code.png`

## Limitations and risks

- The app is Developer ID signed locally but not notarized. `spctl` reports
  `source=Unnotarized Developer ID`. It works on this Mac after local
  installation/registration, but distributing it to other Macs as a binary should
  include Apple notarization.
- The public build defaults to local/ad-hoc signing if no Developer ID
  certificate is available. `script/build_and_run.sh` can use a Developer ID
  certificate automatically or through explicit environment variables.
- A physical reboot was not performed. Persistence is based on normal macOS app
  placement in `/Applications`, LaunchServices registration, pluginkit user
  election, and Quick Look cache reset.
- The renderer intentionally does not execute embedded HTML or remote content
  from Markdown files. Very advanced Markdown extensions outside common
  CommonMark/GFM reading patterns may need future parsing work.

## Reinstall/update command

From this project directory:

```bash
./script/install_app.sh
```
