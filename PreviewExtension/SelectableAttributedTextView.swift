import AppKit
import SwiftUI

struct SelectableAttributedTextView: NSViewRepresentable {
    let attributedText: NSAttributedString
    let openURL: (URL) -> Void
    @Binding var measuredHeight: CGFloat
    @Binding var selectedText: String

    func makeCoordinator() -> Coordinator {
        Coordinator(measuredHeight: $measuredHeight, selectedText: $selectedText, openURL: openURL)
    }

    func makeNSView(context: Context) -> SelectableTextContainerView {
        let view = SelectableTextContainerView()
        view.openURL = context.coordinator.openURL
        view.onHeightChange = { [weak coordinator = context.coordinator] height in
            DispatchQueue.main.async {
                coordinator?.measuredHeight.wrappedValue = height
            }
        }
        view.onSelectedTextChange = { [weak coordinator = context.coordinator] selectedText in
            DispatchQueue.main.async {
                coordinator?.selectedText.wrappedValue = selectedText
            }
        }
        return view
    }

    func updateNSView(_ nsView: SelectableTextContainerView, context: Context) {
        context.coordinator.measuredHeight = $measuredHeight
        context.coordinator.selectedText = $selectedText
        context.coordinator.openURL = openURL
        nsView.setOpenURL(context.coordinator.openURL)
        nsView.setAttributedText(attributedText)
    }

    final class Coordinator {
        var measuredHeight: Binding<CGFloat>
        var selectedText: Binding<String>
        var openURL: (URL) -> Void

        init(
            measuredHeight: Binding<CGFloat>,
            selectedText: Binding<String>,
            openURL: @escaping (URL) -> Void
        ) {
            self.measuredHeight = measuredHeight
            self.selectedText = selectedText
            self.openURL = openURL
        }
    }
}

final class SelectableTextContainerView: NSView, NSTextViewDelegate {
    let textView = PreviewSelectableTextView()

    var onHeightChange: ((CGFloat) -> Void)?
    var onSelectedTextChange: ((String) -> Void)?
    var openURL: ((URL) -> Void)?

    private var currentAttributedText: NSAttributedString?
    private var lastReportedHeight: CGFloat = 0

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.allowsUndo = false
        textView.importsGraphics = false
        textView.usesFindPanel = true
        textView.displaysLinkToolTips = true
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.delegate = self
        textView.openURL = { [weak self] url in
            self?.openURL?(url)
        }
        addSubview(textView)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textViewSelectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        textView.frame = bounds
        recalculateHeight()
    }

    func setAttributedText(_ attributedText: NSAttributedString) {
        if currentAttributedText?.isEqual(to: attributedText) == true {
            return
        }

        currentAttributedText = attributedText.copy() as? NSAttributedString
        textView.textStorage?.setAttributedString(attributedText)
        recalculateHeight()
    }

    func setOpenURL(_ openURL: ((URL) -> Void)?) {
        self.openURL = openURL
        textView.openURL = { [weak self] url in
            self?.openURL?(url)
        }
    }

    @objc private func textViewSelectionDidChange(_ notification: Notification) {
        let selectedText = textView.selectedText
        if !selectedText.isEmpty {
            onSelectedTextChange?(selectedText)
        }
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if let url = link as? URL {
            openURL?(url)
            return true
        }

        if let string = link as? String, let url = URL(string: string) {
            openURL?(url)
            return true
        }

        return false
    }

    private func recalculateHeight() {
        let width = max(bounds.width, 1)
        textView.textContainer?.containerSize = NSSize(
            width: width,
            height: .greatestFiniteMagnitude
        )

        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let height = max(ceil(usedRect.height), 1)

        if abs(height - lastReportedHeight) > 0.5 {
            lastReportedHeight = height
            onHeightChange?(height)
        }
    }
}

final class PreviewSelectableTextView: NSTextView {
    var openURL: ((URL) -> Void)?

    var selectedText: String {
        selectedRanges
            .map(\.rangeValue)
            .filter { $0.length > 0 }
            .map { (string as NSString).substring(with: $0) }
            .joined(separator: "\n")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        let startingPoint = convert(event.locationInWindow, from: nil)
        if let url = resolvedLinkURL(at: startingPoint) {
            openURL?(url)
            return
        }

        super.mouseDown(with: event)

        let endingPoint = window.map { convert($0.mouseLocationOutsideOfEventStream, from: nil) } ?? startingPoint
        guard hypot(endingPoint.x - startingPoint.x, endingPoint.y - startingPoint.y) <= 4 else {
            return
        }

        openLink(at: startingPoint)
    }

    private func resolvedLinkURL(at point: NSPoint) -> URL? {
        guard let textContainer,
              let layoutManager,
              let textStorage else {
            return nil
        }

        var containerPoint = point
        containerPoint.x -= textContainerOrigin.x
        containerPoint.y -= textContainerOrigin.y

        layoutManager.ensureLayout(for: textContainer)
        guard layoutManager.numberOfGlyphs > 0 else {
            return nil
        }

        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        guard glyphIndex < layoutManager.numberOfGlyphs else {
            return nil
        }

        var lineGlyphRange = NSRange(location: 0, length: 0)
        let lineRect = layoutManager.lineFragmentUsedRect(
            forGlyphAt: glyphIndex,
            effectiveRange: &lineGlyphRange
        )
        guard lineRect.insetBy(dx: -2, dy: -3).contains(containerPoint) else {
            return nil
        }

        let characterIndex = layoutManager.characterIndex(
            for: containerPoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        guard characterIndex < textStorage.length else {
            return nil
        }

        var linkRange = NSRange(location: 0, length: 0)
        let link = textStorage.attribute(.link, at: characterIndex, effectiveRange: &linkRange)
        guard let url = resolvedURL(from: link), linkRange.location != NSNotFound else {
            return nil
        }

        let linkGlyphRange = layoutManager.glyphRange(
            forCharacterRange: linkRange,
            actualCharacterRange: nil
        )
        let linkRect = layoutManager.boundingRect(forGlyphRange: linkGlyphRange, in: textContainer)
        guard linkRect.insetBy(dx: -2, dy: -3).contains(containerPoint) else {
            return nil
        }

        return url
    }

    private func openLink(at point: NSPoint) {
        guard let url = resolvedLinkURL(at: point) else {
            return
        }

        openURL?(url)
    }

    private func resolvedURL(from link: Any?) -> URL? {
        if let url = link as? URL {
            return url
        }

        if let string = link as? String {
            return URL(string: string)
        }

        return nil
    }
}
