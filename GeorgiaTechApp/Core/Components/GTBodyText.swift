//
//  GTBodyText.swift
//  GeorgiaTechApp
//

import Foundation
import SwiftUI

/// Long-form copy from the feeds — an article body, an event write-up —
/// set as paragraphs instead of one block.
///
/// The upstream HTML stripper collapses block elements without keeping
/// the newline, so a paragraph break survives only as a RUN of two or
/// more spaces. Splitting on that is what turns a wall of text back into
/// prose; a single space is an ordinary word break and is left alone.
///
/// "Space" here means any Unicode whitespace, because the CMS emits
/// non-breaking (U+00A0) and narrow no-break (U+202F) spaces rather than
/// plain ones — verified against the live feed, where an article's four
/// paragraphs were separated by `\u{A0}\u{A0}` and `\u{202F}\u{202F}\u{A0}`
/// and an ASCII-only rule matched none of them. Lone no-break spaces are
/// normalized to ordinary ones afterwards so long lines still wrap.
struct GTBodyText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(Self.paragraphs(in: text).enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.gtBody1)
                    .foregroundStyle(Color.gtPrimaryText)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Any run of two or more whitespace characters becomes a break —
    /// which also covers real `\n\n`. Empty fragments are dropped so a
    /// longer run doesn't produce blank paragraphs.
    static func paragraphs(in text: String) -> [String] {
        text
            .replacingOccurrences(of: "\\s{2,}", with: "\n\n", options: .regularExpression)
            .components(separatedBy: "\n\n")
            .map {
                $0.replacingOccurrences(
                    of: "[\\u{00A0}\\u{202F}]", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }
}
