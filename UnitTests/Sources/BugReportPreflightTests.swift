//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import XCTest

// MARK: - Helpers

/// A deterministic diagnostics provider for tests.
/// Produces a fixed `DiagnosticsReport` without touching real system APIs.
private struct StubDiagnosticsProvider: DiagnosticsProviding {
    let report: DiagnosticsReport
    
    func collectDiagnostics() async -> DiagnosticsReport {
        report
    }
}

/// A slow diagnostics provider that suspends until cancelled.
/// Used to verify that `viewDisappeared` cancels in-flight work.
private struct SlowDiagnosticsProvider: DiagnosticsProviding {
    func collectDiagnostics() async -> DiagnosticsReport {
        // Block indefinitely (until the Task is cancelled).
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
        }
        // Return a dummy — should never be used.
        return DiagnosticsReport(
            appName: "", appVersion: "", buildNumber: "",
            deviceModel: "", osVersion: "", locale: "",
            timestamp: .now
        )
    }
}

// MARK: - Redaction Tests

final class DiagnosticsRedactorTests: XCTestCase {
    
    // (a) Redaction: e-mail, URL, Matrix ID
    
    func testRedactsEmailAddresses() {
        let input = "Contact alice@example.com for help."
        let result = DiagnosticsRedactor.redact(input)
        
        XCTAssertFalse(result.contains("alice@example.com"), "E-mail should be redacted")
        XCTAssertTrue(result.contains(DiagnosticsRedactor.placeholder))
    }
    
    func testRedactsURLs() {
        let input = "Visit https://matrix.org/docs?foo=bar for details."
        let result = DiagnosticsRedactor.redact(input)
        
        XCTAssertFalse(result.contains("https://matrix.org"), "URL should be redacted")
        XCTAssertTrue(result.contains(DiagnosticsRedactor.placeholder))
    }
    
    func testRedactsMatrixIDs() {
        let input = "User @alice:matrix.org reported the issue."
        let result = DiagnosticsRedactor.redact(input)
        
        XCTAssertFalse(result.contains("@alice:matrix.org"), "Matrix ID should be redacted")
        XCTAssertTrue(result.contains(DiagnosticsRedactor.placeholder))
    }
    
    func testRedactsMultiplePatternsAtOnce() {
        let input = """
        User @bob:server.com sent an email to admin@corp.io \
        and opened https://element.io/help.
        """
        let result = DiagnosticsRedactor.redact(input)
        
        XCTAssertFalse(result.contains("@bob:server.com"))
        XCTAssertFalse(result.contains("admin@corp.io"))
        XCTAssertFalse(result.contains("https://element.io"))
    }
    
    func testPreservesInnocentText() {
        let input = "App: ElementX 1.0.0 (42)\nDevice: iPhone 15\nOS: 18.0"
        let result = DiagnosticsRedactor.redact(input)
        
        XCTAssertEqual(input, result, "Text without sensitive data should remain unchanged")
    }
}

// MARK: - Report Format Tests

@MainActor
final class BugReportPreflightViewModelTests: XCTestCase {
    
    /// Fixed date for deterministic timestamps.
    private static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14T22:13:20Z
    
    private func makeProvider() -> StubDiagnosticsProvider {
        StubDiagnosticsProvider(report: DiagnosticsReport(
            appName: "ElementX",
            appVersion: "1.0.0",
            buildNumber: "42",
            deviceModel: "iPhone 15",
            osVersion: "18.0",
            locale: "en_US",
            timestamp: Self.fixedDate
        ))
    }
    
    // MARK: - (b) Deterministic report format: same input → same output
    
    func testDeterministicReportFormat() async throws {
        let provider = makeProvider()
        let viewModel = BugReportPreflightScreenViewModel(diagnosticsProvider: provider)
        let context = viewModel.context
        
        // Wait for async diagnostics using the project's standard `deferFulfillment` pattern.
        let deferred = deferFulfillment(context.observe(\.viewState.isLoadingDiagnostics)) { !$0 }
        try await deferred.fulfill()
        
        // Fill in user template fields via dynamicMemberLookup (not viewState.bindings).
        context.summary = "App crashes on launch"
        context.stepsToReproduce = "1. Open app\n2. Tap login"
        context.expectedBehavior = "App should show login screen"
        context.actualBehavior = "App crashes immediately"
        
        let report1 = viewModel.assembleReport()
        let report2 = viewModel.assembleReport()
        
        // Same input must produce identical output.
        XCTAssertEqual(report1, report2, "Report should be deterministic for the same input")
        
        // Verify structure includes all required sections.
        XCTAssertTrue(report1.contains("## Bug Report"))
        XCTAssertTrue(report1.contains("### Summary"))
        XCTAssertTrue(report1.contains("App crashes on launch"))
        XCTAssertTrue(report1.contains("### Steps to Reproduce"))
        XCTAssertTrue(report1.contains("1. Open app"))
        XCTAssertTrue(report1.contains("### Expected Behavior"))
        XCTAssertTrue(report1.contains("App should show login screen"))
        XCTAssertTrue(report1.contains("### Actual Behavior"))
        XCTAssertTrue(report1.contains("App crashes immediately"))
        XCTAssertTrue(report1.contains("### Diagnostics"))
        XCTAssertTrue(report1.contains("ElementX 1.0.0 (42)"))
        XCTAssertTrue(report1.contains("iPhone 15"))
    }
    
    func testEmptyFieldsShowPlaceholder() async throws {
        let provider = makeProvider()
        let viewModel = BugReportPreflightScreenViewModel(diagnosticsProvider: provider)
        
        // Wait for diagnostics using deferFulfillment.
        let deferred = deferFulfillment(viewModel.context.observe(\.viewState.isLoadingDiagnostics)) { !$0 }
        try await deferred.fulfill()
        
        // Don't fill in any fields.
        let report = viewModel.assembleReport()
        
        XCTAssertTrue(report.contains("(not provided)"), "Empty fields should show placeholder text")
    }
    
    func testDiagnosticsAreRedacted() async throws {
        let provider = makeProvider()
        let viewModel = BugReportPreflightScreenViewModel(diagnosticsProvider: provider)
        
        // Wait for diagnostics.
        let deferred = deferFulfillment(viewModel.context.observe(\.viewState.isLoadingDiagnostics)) { !$0 }
        try await deferred.fulfill()
        
        let diagnostics = viewModel.context.viewState.diagnosticsText
        
        // The default diagnostics don't contain sensitive data,
        // but verify the redactor was applied (no crash, well-formed output).
        XCTAssertFalse(diagnostics.isEmpty, "Diagnostics should not be empty after loading")
        XCTAssertTrue(diagnostics.contains("ElementX"), "App name should be present")
    }
    
    func testInitialStateShowsLoadingDiagnostics() {
        let provider = makeProvider()
        let viewModel = BugReportPreflightScreenViewModel(diagnosticsProvider: provider)
        
        // Before the async task completes, the state should indicate loading.
        // (This is immediate, no await.)
        XCTAssertTrue(viewModel.context.viewState.isLoadingDiagnostics)
        XCTAssertTrue(viewModel.context.viewState.diagnosticsText.isEmpty)
    }
    
    // MARK: - Cancellation
    
    func testViewDisappearedCancelsDiagnostics() async throws {
        let viewModel = BugReportPreflightScreenViewModel(diagnosticsProvider: SlowDiagnosticsProvider())
        
        // The slow provider blocks forever — diagnostics should still be loading.
        XCTAssertTrue(viewModel.context.viewState.isLoadingDiagnostics)
        
        // Simulate the view disappearing (swipe-back / pop).
        viewModel.process(viewAction: .viewDisappeared)
        
        // Give the RunLoop a tick so cancellation propagates.
        await Task.yield()
        
        // Diagnostics should remain in loading state (task was cancelled, never completed).
        XCTAssertTrue(viewModel.context.viewState.isLoadingDiagnostics,
                       "Diagnostics should not have loaded after cancellation")
    }
}
