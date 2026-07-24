import CmuxAIProviders
import CmuxSettings
import SwiftUI

/// **AI** section — bring-your-own-key AI for the code editor.
///
/// Feature rows (autocomplete + edit selection) bind to `ai.*` defaults;
/// the provider rows pair each base URL with its API key. Keys write to
/// ``AIProviderKeychain`` only — they are never mirrored into defaults,
/// cmux.json, or the search index.
@MainActor
public struct AISection: View {
    @State private var autocompleteEnabled: DefaultsValueModel<Bool>
    @State private var autocompleteProvider: DefaultsValueModel<String>
    @State private var autocompleteModel: DefaultsValueModel<String>
    @State private var editProvider: DefaultsValueModel<String>
    @State private var editModel: DefaultsValueModel<String>
    @State private var anthropicBaseURL: DefaultsValueModel<String>
    @State private var openAIBaseURL: DefaultsValueModel<String>
    @State private var ollamaBaseURL: DefaultsValueModel<String>

    @State private var anthropicKeyDraft = ""
    @State private var openAIKeyDraft = ""
    @State private var anthropicKeyStored = false
    @State private var openAIKeyStored = false

    private let keychain = AIProviderKeychain()

    /// Creates the section bound to the shared defaults store.
    ///
    /// - Parameters:
    ///   - defaultsStore: The settings store.
    ///   - catalog: The setting catalog.
    public init(defaultsStore: UserDefaultsSettingsStore, catalog: SettingCatalog) {
        _autocompleteEnabled = State(initialValue: DefaultsValueModel(store: defaultsStore, key: catalog.ai.autocompleteEnabled))
        _autocompleteProvider = State(initialValue: DefaultsValueModel(store: defaultsStore, key: catalog.ai.autocompleteProvider))
        _autocompleteModel = State(initialValue: DefaultsValueModel(store: defaultsStore, key: catalog.ai.autocompleteModel))
        _editProvider = State(initialValue: DefaultsValueModel(store: defaultsStore, key: catalog.ai.editProvider))
        _editModel = State(initialValue: DefaultsValueModel(store: defaultsStore, key: catalog.ai.editModel))
        _anthropicBaseURL = State(initialValue: DefaultsValueModel(store: defaultsStore, key: catalog.ai.anthropicBaseURL))
        _openAIBaseURL = State(initialValue: DefaultsValueModel(store: defaultsStore, key: catalog.ai.openAIBaseURL))
        _ollamaBaseURL = State(initialValue: DefaultsValueModel(store: defaultsStore, key: catalog.ai.ollamaBaseURL))
    }

    public var body: some View {
        Group {
            SettingsSectionHeader(String(localized: "settings.section.ai", defaultValue: "AI"), section: .ai)
            SettingsCard {
                autocompleteEnabledRow
                SettingsCardDivider()
                providerRow(
                    title: String(localized: "settings.ai.autocompleteProvider", defaultValue: "Autocomplete Provider"),
                    reviewPath: "ai.autocomplete.provider",
                    model: autocompleteProvider
                )
                SettingsCardDivider()
                modelRow(
                    title: String(localized: "settings.ai.autocompleteModel", defaultValue: "Autocomplete Model"),
                    subtitle: String(localized: "settings.ai.autocompleteModel.subtitle", defaultValue: "e.g. qwen2.5-coder:1.5b for Ollama, claude-haiku-4-5-20251001 for Anthropic."),
                    reviewPath: "ai.autocomplete.model",
                    model: autocompleteModel
                )
                SettingsCardDivider()
                providerRow(
                    title: String(localized: "settings.ai.editProvider", defaultValue: "Edit Selection Provider"),
                    reviewPath: "ai.edit.provider",
                    model: editProvider
                )
                SettingsCardDivider()
                modelRow(
                    title: String(localized: "settings.ai.editModel", defaultValue: "Edit Selection Model"),
                    subtitle: String(localized: "settings.ai.editModel.subtitle", defaultValue: "Used by Edit Selection in the code editor."),
                    reviewPath: "ai.edit.model",
                    model: editModel
                )
            }
            SettingsCard {
                keyRow(
                    title: String(localized: "settings.ai.anthropicKey", defaultValue: "Anthropic API Key"),
                    draft: $anthropicKeyDraft,
                    stored: $anthropicKeyStored,
                    provider: "anthropic"
                )
                SettingsCardDivider()
                baseURLRow(
                    title: String(localized: "settings.ai.anthropicBaseURL", defaultValue: "Anthropic Base URL"),
                    reviewPath: "ai.providers.anthropic.baseURL",
                    model: anthropicBaseURL
                )
                SettingsCardDivider()
                keyRow(
                    title: String(localized: "settings.ai.openaiKey", defaultValue: "OpenAI-Compatible API Key"),
                    draft: $openAIKeyDraft,
                    stored: $openAIKeyStored,
                    provider: "openai"
                )
                SettingsCardDivider()
                baseURLRow(
                    title: String(localized: "settings.ai.openaiBaseURL", defaultValue: "OpenAI-Compatible Base URL"),
                    reviewPath: "ai.providers.openai.baseURL",
                    model: openAIBaseURL
                )
                SettingsCardDivider()
                baseURLRow(
                    title: String(localized: "settings.ai.ollamaBaseURL", defaultValue: "Ollama Base URL"),
                    reviewPath: "ai.providers.ollama.baseURL",
                    model: ollamaBaseURL
                )
            }
        }
        .task {
            startObservingSettings()
            anthropicKeyStored = keychain.apiKey(provider: "anthropic") != nil
            openAIKeyStored = keychain.apiKey(provider: "openai") != nil
        }
    }

    private func startObservingSettings() {
        let models: [any SettingObservationStarting] = [
            autocompleteEnabled,
            autocompleteProvider,
            autocompleteModel,
            editProvider,
            editModel,
            anthropicBaseURL,
            openAIBaseURL,
            ollamaBaseURL,
        ]
        models.forEach { $0.startObserving() }
    }

    @ViewBuilder
    private var autocompleteEnabledRow: some View {
        SettingsCardRow(
            configurationReview: .json("ai.autocomplete.enabled"),
            String(localized: "settings.ai.autocompleteEnabled", defaultValue: "Inline Autocomplete"),
            subtitle: String(localized: "settings.ai.autocompleteEnabled.subtitle", defaultValue: "Ghost-text suggestions as you type in the code editor. When off, cmux sends no AI requests.")
        ) {
            Toggle("", isOn: Binding(get: { autocompleteEnabled.current }, set: { autocompleteEnabled.set($0) }))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private func providerRow(
        title: String,
        reviewPath: String,
        model: DefaultsValueModel<String>
    ) -> some View {
        SettingsCardRow(configurationReview: .json(reviewPath), title) {
            Picker("", selection: Binding(get: { model.current }, set: { model.set($0) })) {
                Text(String(localized: "settings.ai.provider.ollama", defaultValue: "Ollama (local)")).tag("ollama")
                Text(String(localized: "settings.ai.provider.anthropic", defaultValue: "Anthropic")).tag("anthropic")
                Text(String(localized: "settings.ai.provider.openai", defaultValue: "OpenAI-Compatible")).tag("openai")
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder
    private func modelRow(
        title: String,
        subtitle: String,
        reviewPath: String,
        model: DefaultsValueModel<String>
    ) -> some View {
        SettingsCardRow(configurationReview: .json(reviewPath), title, subtitle: subtitle) {
            TextField("", text: Binding(get: { model.current }, set: { model.set($0) }))
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
        }
    }

    @ViewBuilder
    private func baseURLRow(
        title: String,
        reviewPath: String,
        model: DefaultsValueModel<String>
    ) -> some View {
        SettingsCardRow(configurationReview: .json(reviewPath), title) {
            TextField("", text: Binding(get: { model.current }, set: { model.set($0) }))
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
        }
    }

    @ViewBuilder
    private func keyRow(
        title: String,
        draft: Binding<String>,
        stored: Binding<Bool>,
        provider: String
    ) -> some View {
        SettingsCardRow(
            title,
            subtitle: String(localized: "settings.ai.key.subtitle", defaultValue: "Stored in the macOS Keychain, never in settings files.")
        ) {
            HStack(spacing: 6) {
                SecureField(
                    stored.wrappedValue
                        ? String(localized: "settings.ai.key.saved", defaultValue: "Saved")
                        : String(localized: "settings.ai.key.placeholder", defaultValue: "API key"),
                    text: draft
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)
                Button(String(localized: "settings.ai.key.save", defaultValue: "Save")) {
                    if keychain.setAPIKey(draft.wrappedValue, provider: provider) {
                        stored.wrappedValue = !draft.wrappedValue.isEmpty
                        draft.wrappedValue = ""
                    }
                }
                .disabled(draft.wrappedValue.isEmpty)
                Button(String(localized: "settings.ai.key.remove", defaultValue: "Remove")) {
                    if keychain.deleteAPIKey(provider: provider) {
                        stored.wrappedValue = false
                        draft.wrappedValue = ""
                    }
                }
                .disabled(!stored.wrappedValue)
            }
        }
    }
}
