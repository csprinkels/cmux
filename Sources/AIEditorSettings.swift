import CmuxAIProviders
import Foundation

/// Resolves the `ai.*` settings into ``AIProviderConfiguration`` values.
///
/// This is the single mapping from settings + Keychain to a callable
/// endpoint: both editor AI features (autocomplete and edit-selection) route
/// through here so provider selection, base URLs, wire formats, and key
/// lookup never fork per feature.
enum AIEditorSettings {
    /// The provider ids settings accept.
    static let validProviders: Set<String> = ["anthropic", "openai", "ollama"]

    /// One feature's provider/model selection.
    struct FeatureSelection: Equatable {
        /// The provider id (`anthropic`, `openai`, `ollama`).
        let provider: String
        /// The model identifier; empty when the user has not chosen one.
        let model: String

        /// Whether the selection is complete enough to send requests.
        var isConfigured: Bool { !model.isEmpty }
    }

    /// Whether inline autocomplete is enabled (`ai.autocomplete.enabled`).
    static func isAutocompleteEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: "ai.autocomplete.enabled")
    }

    /// The autocomplete provider/model selection.
    static func autocompleteSelection(defaults: UserDefaults = .standard) -> FeatureSelection {
        FeatureSelection(
            provider: providerID(forKey: "ai.autocomplete.provider", defaults: defaults),
            model: defaults.string(forKey: "ai.autocomplete.model") ?? ""
        )
    }

    /// The edit-selection provider/model selection.
    static func editSelection(defaults: UserDefaults = .standard) -> FeatureSelection {
        FeatureSelection(
            provider: providerID(forKey: "ai.edit.provider", defaults: defaults),
            model: defaults.string(forKey: "ai.edit.model") ?? ""
        )
    }

    /// Builds the endpoint configuration for one feature selection, reading
    /// the provider's base URL from defaults and its key from the Keychain.
    ///
    /// - Parameters:
    ///   - selection: The feature's provider/model choice.
    ///   - defaults: Defaults store; injectable for tests.
    ///   - keychain: Key storage; injectable for tests.
    /// - Returns: A configuration, or `nil` when the selection is incomplete
    ///   or the base URL is invalid.
    static func configuration(
        for selection: FeatureSelection,
        defaults: UserDefaults = .standard,
        keychain: AIProviderKeychain = AIProviderKeychain()
    ) -> AIProviderConfiguration? {
        guard selection.isConfigured else { return nil }
        guard let baseURL = URL(string: baseURLString(provider: selection.provider, defaults: defaults)),
              baseURL.scheme == "http" || baseURL.scheme == "https" else {
            return nil
        }
        return AIProviderConfiguration(
            baseURL: baseURL,
            model: selection.model,
            wireFormat: selection.provider == "anthropic" ? .anthropicMessages : .openAIChatCompletions,
            apiKey: keychain.apiKey(provider: selection.provider)
        )
    }

    /// The stored base URL string for a provider id, with built-in defaults.
    static func baseURLString(provider: String, defaults: UserDefaults = .standard) -> String {
        if let stored = defaults.string(forKey: "ai.providers.\(provider).baseURL"), !stored.isEmpty {
            return stored
        }
        switch provider {
        case "anthropic": return "https://api.anthropic.com"
        case "openai": return "https://api.openai.com"
        default: return "http://localhost:11434"
        }
    }

    private static func providerID(forKey key: String, defaults: UserDefaults) -> String {
        let stored = defaults.string(forKey: key) ?? ""
        return validProviders.contains(stored) ? stored : "ollama"
    }
}
