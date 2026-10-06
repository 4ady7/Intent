import FamilyControls

extension PersistedSelection {
    init(familySelection: FamilyActivitySelection) {
        self.init(
            applicationTokens: familySelection.applicationTokens,
            categoryTokens: familySelection.categoryTokens,
            webDomainTokens: familySelection.webDomainTokens,
            includeEntireCategory: familySelection.includeEntireCategory
        )
    }

    func familySelection() -> FamilyActivitySelection {
        var selection = FamilyActivitySelection(includeEntireCategory: includeEntireCategory)
        selection.applicationTokens = applicationTokens
        selection.categoryTokens = categoryTokens
        selection.webDomainTokens = webDomainTokens
        return selection
    }
}

enum SelectionDescription {
    static func headline(_ selection: PersistedSelection) -> String {
        let count = selection.distractionCount
        if count == 0 {
            return "Nothing selected yet"
        }
        return count == 1 ? "1 selected" : "\(count) selected"
    }

    static func breakdown(_ selection: PersistedSelection) -> String {
        var parts: [String] = []
        let apps = selection.applicationTokens.count
        let categories = selection.categoryTokens.count
        let websites = selection.webDomainTokens.count
        if apps > 0 {
            parts.append(apps == 1 ? "1 app" : "\(apps) apps")
        }
        if categories > 0 {
            parts.append(categories == 1 ? "1 category" : "\(categories) categories")
        }
        if websites > 0 {
            parts.append(websites == 1 ? "1 website" : "\(websites) websites")
        }
        return parts.joined(separator: ", ")
    }
}
