//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// Redacts potentially sensitive information from text.
///
/// Supported patterns:
/// - E-mail addresses (RFC 5322 simplified)
/// - URLs (http/https)
/// - Matrix IDs (`@localpart:server`)
enum DiagnosticsRedactor {
    /// The placeholder string used for redacted content.
    static let placeholder = "[REDACTED]"
    
    // MARK: - Patterns
    
    /// Simplified e-mail regex.
    private static let emailPattern = #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#
    
    /// HTTP/HTTPS URL regex.
    private static let urlPattern = #"https?://[^\s<>\"\)\]]+"#
    
    /// Matrix ID pattern: @localpart:server.tld (localpart can include -, ., _, =, /)
    private static let matrixIDPattern = #"@[A-Za-z0-9._=\-/]+:[A-Za-z0-9.\-]+"#
    
    // MARK: - Public API
    
    /// Returns a copy of `text` with all sensitive fragments replaced by `[REDACTED]`.
    static func redact(_ text: String) -> String {
        var result = text
        
        // Order matters: redact URLs first (they may contain e-mail-like fragments).
        for pattern in [urlPattern, emailPattern, matrixIDPattern] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result,
                                                    range: range,
                                                    withTemplate: placeholder)
        }
        
        return result
    }
}
