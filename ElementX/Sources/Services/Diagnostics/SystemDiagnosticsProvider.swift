//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import UIKit

/// Concrete implementation of `DiagnosticsProviding` that reads system info.
///
/// Deliberately independent from any SDK/FFI layer so that future Rust SDK
/// changes never break this component.
final class SystemDiagnosticsProvider: DiagnosticsProviding {
    // Store values captured on MainActor at init time so that
    // `collectDiagnostics()` is safe to call from any context.
    private let appName: String
    private let appVersion: String
    private let buildNumber: String
    private let deviceModel: String
    private let osVersion: String
    private let locale: String
    
    /// Initializer with sensible system defaults.
    /// All parameters are injectable for preview and testing purposes.
    @MainActor
    init(appName: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "ElementX",
         appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown",
         buildNumber: String = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "Unknown",
         deviceModel: String = UIDevice.current.model,
         osVersion: String = UIDevice.current.systemVersion,
         locale: String = Locale.current.identifier) {
        self.appName = appName
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.locale = locale
    }
    
    func collectDiagnostics() async -> DiagnosticsReport {
        // In production this method may call into SDK/FFI layers;
        // cooperative cancellation is handled by the caller (ViewModel).
        DiagnosticsReport(appName: appName,
                          appVersion: appVersion,
                          buildNumber: buildNumber,
                          deviceModel: deviceModel,
                          osVersion: osVersion,
                          locale: locale,
                          timestamp: .now)
    }
}
