//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// A single diagnostics snapshot containing device/app metadata.
struct DiagnosticsReport: Equatable, Sendable {
    let appName: String
    let appVersion: String
    let buildNumber: String
    let deviceModel: String
    let osVersion: String
    let locale: String
    let timestamp: Date
    
    /// Renders a human-readable multiline string.
    func formatted() -> String {
        let dateFormatter = ISO8601DateFormatter()
        let ts = dateFormatter.string(from: timestamp)
        return """
        App: \(appName) \(appVersion) (\(buildNumber))
        Device: \(deviceModel)
        OS: \(osVersion)
        Locale: \(locale)
        Timestamp: \(ts)
        """
    }
}

/// Abstract provider of system diagnostics.
/// Implementations must be UI-independent and safe for reuse across layers.
// sourcery: AutoMockable
protocol DiagnosticsProviding: Sendable {
    /// Collects diagnostics asynchronously; supports cooperative cancellation.
    func collectDiagnostics() async -> DiagnosticsReport
}
