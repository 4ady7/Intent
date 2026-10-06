import FamilyControls
import Foundation
import ManagedSettings

enum BlockingService {
    static func apply(_ selection: PersistedSelection) throws {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved:
            break
        case .denied:
            throw FocusError.notAuthorized
        default:
            throw FocusError.authorizationUnavailable
        }
        guard selection.hasSelection else {
            throw FocusError.nothingSelected
        }

        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(FocusIdentifiers.settingsStoreName))
        store.clearAllSettings()

        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
            store.shield.webDomainCategories = .specific(selection.categoryTokens)
        }
        if !selection.webDomainTokens.isEmpty {
            store.shield.webDomains = selection.webDomainTokens
        }

        try verify(store, matches: selection)
    }

    static func clear() throws {
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(FocusIdentifiers.settingsStoreName))
        store.clearAllSettings()
        if !isCleared(store) {
            throw FocusError.restrictionsNotCleared
        }
    }

    private static func verify(_ store: ManagedSettingsStore, matches selection: PersistedSelection) throws {
        let applications = store.shield.applications ?? []
        let webDomains = store.shield.webDomains ?? []
        guard applications == selection.applicationTokens else {
            throw FocusError.restrictionsNotApplied
        }
        guard webDomains == selection.webDomainTokens else {
            throw FocusError.restrictionsNotApplied
        }
        let expectedCategories = !selection.categoryTokens.isEmpty
        let hasApplicationCategories = store.shield.applicationCategories != nil
        let hasWebCategories = store.shield.webDomainCategories != nil
        guard hasApplicationCategories == expectedCategories, hasWebCategories == expectedCategories else {
            throw FocusError.restrictionsNotApplied
        }
    }

    private static func isCleared(_ store: ManagedSettingsStore) -> Bool {
        let applications = store.shield.applications ?? []
        let webDomains = store.shield.webDomains ?? []
        return applications.isEmpty
            && webDomains.isEmpty
            && store.shield.applicationCategories == nil
            && store.shield.webDomainCategories == nil
    }
}
