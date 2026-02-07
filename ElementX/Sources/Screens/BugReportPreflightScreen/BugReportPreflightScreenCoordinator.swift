//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

enum BugReportPreflightScreenCoordinatorAction {
    case dismiss
}

struct BugReportPreflightScreenCoordinatorParameters {
    let diagnosticsProvider: DiagnosticsProviding
}

final class BugReportPreflightScreenCoordinator: CoordinatorProtocol {
    private let parameters: BugReportPreflightScreenCoordinatorParameters
    private var viewModel: BugReportPreflightScreenViewModelProtocol
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<BugReportPreflightScreenCoordinatorAction, Never> = .init()
    var actions: AnyPublisher<BugReportPreflightScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: BugReportPreflightScreenCoordinatorParameters) {
        self.parameters = parameters
        viewModel = BugReportPreflightScreenViewModel(diagnosticsProvider: parameters.diagnosticsProvider)
        
        // Subscribe in init (same pattern as SettingsScreenCoordinator).
        viewModel.actions
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .dismiss:
                    actionsSubject.send(.dismiss)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public
    
    func toPresentable() -> AnyView {
        AnyView(BugReportPreflightScreen(context: viewModel.context))
    }
}
