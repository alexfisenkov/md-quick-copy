# MD Quick Copy

Native macOS Quick Look previews for Markdown files, with selectable rendered
text, clickable links, and visible copy buttons for fenced code blocks and
Markdown tables.

Select a `.md` file in Finder, press Space, and Markdown opens as a readable
preview instead of raw text. Code blocks get a `Copy` button that writes the
block to the macOS clipboard. Tables get copy controls for Markdown, CSV, and
TSV. Rendered Markdown text can be partially selected with the mouse; a visible
`Copy selection` button appears for the selected range.

## Features

- Quick Look preview extension for `.md` and `.markdown` files.
- Native SwiftUI/AppKit renderer, no WebKit dependency.
- Selectable rendered Markdown text with a visible partial-copy button.
- Clickable Markdown links and bare URLs in text blocks, with a clipboard
  fallback if the Quick Look host refuses to open a URL.
- GitHub-Flavored Markdown tables with column alignment.
- Table copy buttons for Markdown, CSV, and TSV.
- Document outline for Markdown files with multiple headings.
- Backtick fences, tilde fences, indented code blocks, and exported
  language-label code blocks such as `JSON` or `Ini, TOML`.
- Visible copy buttons for fenced code blocks.
- Headings, paragraphs, ordered/unordered lists, task lists, blockquotes, and
  horizontal rules.
- Host app with install status, GitHub access, and maintenance commands.
- Clipboard integration through `NSPasteboard`.
- UTF-8 reading with Windows CP1251 and ISO Latin 1 fallbacks.
- Local install into `/Applications`.

## Requirements

- macOS 14 or newer.
- Xcode with command line tools.
- Optional: [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you want to
  regenerate the Xcode project from `project.yml`.

Install XcodeGen with Homebrew:

```bash
brew install xcodegen
```

## Install

Clone the repository and run the installer:

```bash
git clone https://github.com/alexfisenkov/md-quick-copy.git
cd md-quick-copy
./script/install_app.sh
```

The installer will:

- build a Release app;
- copy `MD Quick Copy.app` to `/Applications`;
- register the Quick Look extension with LaunchServices and `pluginkit`;
- reset the Quick Look cache;
- ignore the `QLMarkdown` extension if it is installed, so Finder uses
  `MD Quick Copy`.

After installation, select any `.md` file in Finder and press Space.

## Signing

For local use, the build can be signed ad-hoc. If a Developer ID Application
certificate is available in your keychain, `script/build_and_run.sh` will use
the first matching certificate automatically.

You can also specify signing manually:

```bash
MD_QUICK_COPY_CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
MD_QUICK_COPY_DEVELOPMENT_TEAM="TEAMID" \
./script/install_app.sh
```

This repository does not ship notarized release binaries yet. If you distribute
the app to other Macs as a binary, notarize it with Apple first.

## Update

```bash
git pull
./script/install_app.sh
```

## Uninstall

```bash
pluginkit -r "/Applications/MD Quick Copy.app/Contents/PlugIns/MD Quick Copy Preview Extension.appex" || true
rm -rf "/Applications/MD Quick Copy.app"
qlmanage -r
qlmanage -r cache
```

## Development

Generate the Xcode project:

```bash
xcodegen generate --spec project.yml --project .
```

Run tests:

```bash
xcodebuild test -project MDQuickCopy.xcodeproj -scheme MDQuickCopyCoreTests -destination 'platform=macOS'
```

Build and install locally:

```bash
./script/install_app.sh
```

GitHub Actions runs the same project generation, tests, and Release build on
pushes and pull requests.

## Scope

`MD Quick Copy` is a Quick Look preview extension, not a Markdown editor. It
uses a native renderer for predictable Quick Look behavior and avoids executing
HTML, scripts, or remote content from Markdown files. Very advanced Markdown
extensions outside common CommonMark/GFM reading patterns may still need future
parsing work. Links open through the Quick Look extension context; if macOS
refuses the open request, the URL is copied to the clipboard instead. Quick Look
does not reliably give preview extensions normal first-responder ownership, so
partial text copying is exposed through the visible `Copy selection` button
instead of relying on Command-C. Markdown HTML blocks are intentionally not
executed.

## Release history

See `CHANGELOG.md`.

## License

MIT
