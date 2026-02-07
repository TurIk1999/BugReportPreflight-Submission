//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct BugReportPreflightScreen: View {
    @Bindable var context: BugReportPreflightScreenViewModel.Context
    
    @State private var showShareSheet = false
    
    var body: some View {
        Form {
            templateSection
            diagnosticsSection
            actionsSection
        }
        .compoundList()
        .navigationTitle(L10n.commonReportAProblem)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .onDisappear {
            context.send(viewAction: .viewDisappeared)
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: [context.viewState.assembledReport])
        }
    }
    
    // MARK: - Sections
    
    // TODO: Add L10n keys for field labels (Localazy sync required, see project CONTRIBUTING.md).
    
    private var templateSection: some View {
        Section {
            ListRow(label: .plain(title: "Summary"),
                    kind: .textField(text: $context.summary, axis: .vertical))
                .lineLimit(2, reservesSpace: true)
                .accessibilityIdentifier(A11yIdentifiers.bugReportPreflightScreen.summary)
            
            ListRow(label: .plain(title: "Steps to Reproduce"),
                    kind: .textField(text: $context.stepsToReproduce, axis: .vertical))
                .lineLimit(4, reservesSpace: true)
                .accessibilityIdentifier(A11yIdentifiers.bugReportPreflightScreen.stepsToReproduce)
            
            ListRow(label: .plain(title: "Expected Behavior"),
                    kind: .textField(text: $context.expectedBehavior, axis: .vertical))
                .lineLimit(2, reservesSpace: true)
                .accessibilityIdentifier(A11yIdentifiers.bugReportPreflightScreen.expectedBehavior)
            
            ListRow(label: .plain(title: "Actual Behavior"),
                    kind: .textField(text: $context.actualBehavior, axis: .vertical))
                .lineLimit(2, reservesSpace: true)
                .accessibilityIdentifier(A11yIdentifiers.bugReportPreflightScreen.actualBehavior)
        } header: {
            Text("Bug Details")
                .compoundListSectionHeader()
        }
    }
    
    private var diagnosticsSection: some View {
        Section {
            if context.viewState.isLoadingDiagnostics {
                HStack {
                    ProgressView()
                    Text("Collecting diagnostics…")
                        .font(.compound.bodyMD)
                        .foregroundStyle(.compound.textSecondary)
                }
                .padding(.vertical, 8)
            } else {
                Text(context.viewState.diagnosticsText)
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textSecondary)
                    .padding(.vertical, 4)
                    .accessibilityIdentifier(A11yIdentifiers.bugReportPreflightScreen.diagnostics)
            }
        } header: {
            Text("Diagnostics")
                .compoundListSectionHeader()
        } footer: {
            Text("Sensitive data (emails, URLs, Matrix IDs) is automatically redacted.")
                .compoundListSectionFooter()
        }
    }
    
    private var actionsSection: some View {
        Section {
            Button {
                context.send(viewAction: .copyToClipboard)
            } label: {
                Label(L10n.actionCopy, systemImage: "doc.on.doc")
            }
            .accessibilityIdentifier(A11yIdentifiers.bugReportPreflightScreen.copyToClipboard)
            
            Button {
                context.send(viewAction: .share)
                showShareSheet = true
            } label: {
                Label(L10n.actionShare, systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier(A11yIdentifiers.bugReportPreflightScreen.share)
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(L10n.actionDone) {
                context.send(viewAction: .dismiss)
            }
        }
    }
}

// MARK: - UIActivityViewController Wrapper

/// Minimal wrapper around `UIActivityViewController` for SwiftUI share sheet.
private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

// MARK: - Previews

struct BugReportPreflightScreen_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        NavigationStack {
            BugReportPreflightScreen(context: BugReportPreflightScreenViewModel(
                diagnosticsProvider: SystemDiagnosticsProvider(
                    appName: "ElementX",
                    appVersion: "1.0.0",
                    buildNumber: "42",
                    deviceModel: "iPhone 15",
                    osVersion: "18.0",
                    locale: "en_US"
                )
            ).context)
        }
    }
}
