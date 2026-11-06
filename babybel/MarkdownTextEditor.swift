import AppKit
import SwiftUI

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        applyMarkdownStyles(to: textView)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        scrollView.verticalRulerView = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.update(text: $text)
        guard textView.string != text else { return }
        let selection = textView.selectedRange()
        textView.string = text
        applyMarkdownStyles(to: textView)
        textView.setSelectedRange(NSRange(location: min(selection.location, (text as NSString).length), length: 0))
        scrollView.verticalRulerView?.needsDisplay = true
    }

    private func applyMarkdownStyles(to textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let source = textView.string as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        let baseFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        paragraph.paragraphSpacing = 4
        storage.beginEditing()
        storage.setAttributes([
            .font: baseFont,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraph
        ], range: fullRange)

        apply(pattern: "(?m)^#{1,4}\\s+.*$", to: storage, source: source, fullRange: fullRange) { range in
            let marker = source.substring(with: range).prefix { $0 == "#" }.count
            let size: CGFloat = [1: 23, 2: 19, 3: 16, 4: 14][marker] ?? 14
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: size, weight: .bold), range: range)
            storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
        }
        apply(pattern: "(?m)^>.*$", to: storage, source: source, fullRange: fullRange) { range in
            storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range)
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .medium), range: range)
        }
        apply(pattern: "`[^`]+`", to: storage, source: source, fullRange: fullRange) { range in
            storage.addAttribute(.backgroundColor, value: NSColor.quaternaryLabelColor.withAlphaComponent(0.18), range: range)
            storage.addAttribute(.foregroundColor, value: NSColor.systemBrown, range: range)
        }
        apply(pattern: "\\*\\*.+?\\*\\*|__.+?__", to: storage, source: source, fullRange: fullRange) { range in
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold), range: range)
        }
        apply(pattern: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)|(?<!_)_(?!_)(.+?)(?<!_)_(?!_)",
              to: storage, source: source, fullRange: fullRange) { range in
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: range)
            storage.addAttribute(.obliqueness, value: 0.2, range: range)
        }
        storage.endEditing()
        textView.typingAttributes = [
            .font: baseFont,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraph
        ]
    }

    private func apply(
        pattern: String,
        to storage: NSTextStorage,
        source: NSString,
        fullRange: NSRange,
        style: (NSRange) -> Void
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        regex.enumerateMatches(in: source as String, range: fullRange) { match, _, _ in
            guard let range = match?.range else { return }
            style(range)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: NSTextView?

        init(text: Binding<String>) {
            _text = text
        }

        func update(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text = textView.string
            let selection = textView.selectedRange()
            // Re-apply syntax styles after each edit while retaining the insertion point.
            let editor = MarkdownTextEditor(text: $text)
            editor.applyMarkdownStyles(to: textView)
            textView.setSelectedRange(NSRange(location: min(selection.location, (textView.string as NSString).length), length: 0))
            (textView.enclosingScrollView?.verticalRulerView as? LineNumberRulerView)?.needsDisplay = true
        }
    }
}

private final class LineNumberRulerView: NSRulerView {
    private let textView: NSTextView
    private let labelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
        .foregroundColor: NSColor.tertiaryLabelColor
    ]

    init(scrollView: NSScrollView, orientation: NSRulerView.Orientation) {
        guard let textView = scrollView.documentView as? NSTextView else {
            fatalError("Line number ruler requires a text view")
        }
        self.textView = textView
        super.init(scrollView: scrollView, orientation: orientation)
        ruleThickness = 42
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        NSColor.textBackgroundColor.setFill()
        rect.fill()

        let visibleGlyphs = layoutManager.glyphRange(forBoundingRect: scrollView?.contentView.bounds ?? rect, in: textContainer)
        let source = textView.string as NSString
        var lastLine = 0
        layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphs) { lineRect, _, _, glyphRange, _ in
            let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let lineNumber = source.substring(to: min(characterRange.location, source.length)).filter { $0 == "\n" }.count + 1
            guard lineNumber != lastLine else { return }
            lastLine = lineNumber
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: self.labelAttributes)
            let origin = NSPoint(x: self.ruleThickness - size.width - 8,
                                 y: lineRect.minY + self.textView.textContainerOrigin.y + 2)
            label.draw(at: origin, withAttributes: self.labelAttributes)
        }
    }
}
