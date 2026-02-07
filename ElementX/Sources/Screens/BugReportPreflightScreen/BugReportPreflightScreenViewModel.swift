//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias BugReportPreflightScreenViewModelType = StateStoreViewModelV2<BugReportPreflightScreenViewState, BugReportPreflightScreenViewAction>

class BugReportPreflightScreenViewModel: BugReportPreflightScreenViewModelType, BugReportPreflightScreenViewModelProtocol {
    private let diagnosticsProvider: DiagnosticsProviding
    
    private let actionsSubject: PassthroughSubject<BugReportPreflightScreenViewModelAction, Never> = .init()
    // periphery:ignore - when set to nil this is automatically cancelled
    @CancellableTask private var diagnosticsTask: Task<Void, Never>?
    
    var actions: AnyPublisher<BugReportPreflightScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(diagnosticsProvider: DiagnosticsProviding) {
        self.diagnosticsProvider = diagnosticsProvider
        
        let bindings = BugReportPreflightScreenViewStateBindings(
            summary: "",
            stepsToReproduce: "",
            expectedBehavior: "",
            actualBehavior: ""
        )
        
        super.init(initialViewState: BugReportPreflightScreenViewState(
            isLoadingDiagnostics: true,
            assembledReport: "",
            diagnosticsText: "",
            bindings: bindings
        ))
        
        loadDiagnostics()
    }
    
    // MARK: - Public
    
    override func process(viewAction: BugReportPreflightScreenViewAction) {
        switch viewAction {
        case .dismiss:
            diagnosticsTask = nil
            actionsSubject.send(.dismiss)
        case .copyToClipboard:
            let report = assembleReport()
            UIPasteboard.general.string = report
        case .share:
            // The view handles the share sheet presentation using assembledReport.
            state.assembledReport = assembleReport()
        case .viewDisappeared:
            // Cancel any in-flight diagnostics collection without navigating.
            // Covers swipe-back and programmatic pop that bypass .dismiss.
            diagnosticsTask = nil
        }
    }
    
    // MARK: - Private
    
    private func loadDiagnostics() {
        diagnosticsTask = Task { [weak self] in
            guard let self else { return }
            
            let report = await diagnosticsProvider.collectDiagnostics()
            
            guard !Task.isCancelled else { return }
            
            let formatted = report.formatted()
            let redacted = DiagnosticsRedactor.redact(formatted)
            
            state.diagnosticsText = redacted
            state.isLoadingDiagnostics = false
        }
    }
    
    // MARK: - Report Assembly
    
    /// Assembles the complete report from user-entered fields and diagnostics.
    func assembleReport() -> String {
        let fields = context.viewState.bindings
        
        return """
        ## Bug Report
        
        ### Summary
        \(fields.summary.isEmpty ? "(not provided)" : fields.summary)
        
        ### Steps to Reproduce
        \(fields.stepsToReproduce.isEmpty ? "(not provided)" : fields.stepsToReproduce)
        
        ### Expected Behavior
        \(fields.expectedBehavior.isEmpty ? "(not provided)" : fields.expectedBehavior)
        
        ### Actual Behavior
        \(fields.actualBehavior.isEmpty ? "(not provided)" : fields.actualBehavior)
        
        ### Diagnostics
        \(state.diagnosticsText.isEmpty ? "(loading…)" : state.diagnosticsText)
        """
    }
}
