import Combine
import Foundation
import ServiceManagement

/// Preferences kept in UserDefaults. Read by the monitor, the store and the UI.
@MainActor
public final class AppSettings: ObservableObject {
    private enum Key {
        static let maxItems = "maxItems"
        static let keepDays = "keepDays"
        static let saveImages = "saveImagesAndFiles"
        static let skipSecrets = "skipSecrets"
        static let paused = "isPaused"
        static let nearCaret = "panelNearCaret"
        static let onboarding = "onboardingDone"
        static let hotKey = "hotKey"
    }

    private let defaults: UserDefaults

    @Published public var maxItems: Int {
        didSet { defaults.set(maxItems, forKey: Key.maxItems) }
    }
    @Published public var keepDays: Int {
        didSet { defaults.set(keepDays, forKey: Key.keepDays) }
    }
    @Published public var saveImagesAndFiles: Bool {
        didSet { defaults.set(saveImagesAndFiles, forKey: Key.saveImages) }
    }
    @Published public var skipSecrets: Bool {
        didSet { defaults.set(skipSecrets, forKey: Key.skipSecrets) }
    }
    @Published public var isPaused: Bool {
        didSet { defaults.set(isPaused, forKey: Key.paused) }
    }
    @Published public var panelNearCaret: Bool {
        didSet { defaults.set(panelNearCaret, forKey: Key.nearCaret) }
    }
    @Published public var onboardingDone: Bool {
        didSet { defaults.set(onboardingDone, forKey: Key.onboarding) }
    }
    @Published public var hotKey: HotKeySpec {
        didSet {
            if let data = try? JSONEncoder().encode(hotKey) {
                defaults.set(data, forKey: Key.hotKey)
            }
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        maxItems = defaults.object(forKey: Key.maxItems) as? Int ?? 500
        keepDays = defaults.object(forKey: Key.keepDays) as? Int ?? 30
        saveImagesAndFiles = defaults.object(forKey: Key.saveImages) as? Bool ?? true
        skipSecrets = defaults.object(forKey: Key.skipSecrets) as? Bool ?? true
        isPaused = defaults.bool(forKey: Key.paused)
        panelNearCaret = defaults.object(forKey: Key.nearCaret) as? Bool ?? true
        onboardingDone = defaults.bool(forKey: Key.onboarding)
        if let data = defaults.data(forKey: Key.hotKey),
           let saved = try? JSONDecoder().decode(HotKeySpec.self, from: data) {
            hotKey = saved
        } else {
            hotKey = .defaultOpen
        }
    }

    public var retention: RetentionPolicy {
        RetentionPolicy(maxItems: maxItems, keepDays: keepDays)
    }
}

public enum LaunchAtLoginState: Sendable, Equatable {
    case enabled, disabled, needsApproval
}

/// Start the app at login, through the system's login item list.
public enum LaunchAtLogin {
    public static var state: LaunchAtLoginState {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .needsApproval
        default: return .disabled
        }
    }

    public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
