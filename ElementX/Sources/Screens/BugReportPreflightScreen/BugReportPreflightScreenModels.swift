//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

// MARK: - ViewModel → Coordinator

enum BugReportPreflightScreenViewModelAction {
    case dismiss
}

// MARK: - View State

struct BugReportPreflightScreenViewState: BindableState {
    /// Whether diagnostics are still being collected.
    var isLoadingDiagnostics: Bool
    /// The final assembled report text (diagnostics included).
    var assembledReport: String
    /// Diagnostics block (redacted) for display.
    var diagnosticsText: String
    
    var bindings: BugReportPreflightScreenViewStateBindings
}

struct BugReportPreflightScreenViewStateBindings {
    var summary: String
    var stepsToReproduce: String
    var expectedBehavior: String
    var actualBehavior: String
}

// MARK: - View → ViewModel

enum BugReportPreflightScreenViewAction {
    case dismiss
    case copyToClipboard
    case share
    /// Sent from `.onDisappear` — cancels background diagnostics without navigating.
    case viewDisappeared
}
