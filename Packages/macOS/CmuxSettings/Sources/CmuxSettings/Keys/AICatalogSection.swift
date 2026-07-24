import Foundation

/// Settings under the dotted-id prefix `ai.*`.
///
/// Bring-your-own-key AI for the code editor: inline autocomplete and the
/// edit-selection command. Provider API keys are NOT settings — they live in
/// the Keychain (`AIProviderKeychain`) and never appear in defaults, cmux.json,
/// or the schema. Providers are identified by fixed ids: `anthropic`
/// (Messages wire format), `openai` and `ollama` (OpenAI-compatible wire
/// format); pointing `openai`'s base URL at any compatible server (LM Studio,
/// OpenRouter, vLLM) is the supported custom path.
public struct AICatalogSection: SettingCatalogSection {
    /// Whether inline ghost-text autocomplete is active in the code editor.
    ///
    /// `false` (the default) sends zero AI requests — the editor behaves
    /// exactly as before the feature existed.
    public let autocompleteEnabled = DefaultsKey<Bool>(
        id: "ai.autocomplete.enabled",
        defaultValue: false,
        userDefaultsKey: "ai.autocomplete.enabled"
    )

    /// The provider id autocomplete uses: `anthropic`, `openai`, or `ollama`.
    ///
    /// Defaults to `ollama` so the offline, keyless local path is the
    /// zero-configuration one.
    public let autocompleteProvider = DefaultsKey<String>(
        id: "ai.autocomplete.provider",
        defaultValue: "ollama",
        userDefaultsKey: "ai.autocomplete.provider"
    )

    /// The model autocomplete requests, e.g. `qwen2.5-coder:1.5b` or
    /// `claude-haiku-4-5-20251001`. Empty disables the feature with a hint in
    /// the editor.
    public let autocompleteModel = DefaultsKey<String>(
        id: "ai.autocomplete.model",
        defaultValue: "",
        userDefaultsKey: "ai.autocomplete.model"
    )

    /// The provider id the edit-selection command uses.
    public let editProvider = DefaultsKey<String>(
        id: "ai.edit.provider",
        defaultValue: "ollama",
        userDefaultsKey: "ai.edit.provider"
    )

    /// The model the edit-selection command requests. Empty disables the
    /// command with a hint.
    public let editModel = DefaultsKey<String>(
        id: "ai.edit.model",
        defaultValue: "",
        userDefaultsKey: "ai.edit.model"
    )

    /// Endpoint origin for the `anthropic` provider.
    public let anthropicBaseURL = DefaultsKey<String>(
        id: "ai.providers.anthropic.baseURL",
        defaultValue: "https://api.anthropic.com",
        userDefaultsKey: "ai.providers.anthropic.baseURL"
    )

    /// Endpoint origin for the `openai` provider; point this at any
    /// OpenAI-compatible server to use a custom endpoint.
    public let openAIBaseURL = DefaultsKey<String>(
        id: "ai.providers.openai.baseURL",
        defaultValue: "https://api.openai.com",
        userDefaultsKey: "ai.providers.openai.baseURL"
    )

    /// Endpoint origin for the `ollama` provider (keyless, local by default).
    public let ollamaBaseURL = DefaultsKey<String>(
        id: "ai.providers.ollama.baseURL",
        defaultValue: "http://localhost:11434",
        userDefaultsKey: "ai.providers.ollama.baseURL"
    )

    /// Creates the AI settings section with its default keys.
    public init() {}
}
