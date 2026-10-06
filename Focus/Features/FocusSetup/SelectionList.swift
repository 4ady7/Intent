import FamilyControls
import ManagedSettings
import SwiftUI

struct SelectionList: View {
    let selection: PersistedSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(selection.orderedApplications, id: \.self) { token in
                Label(token)
                    .font(.body)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            ForEach(selection.orderedCategories, id: \.self) { token in
                Label(token)
                    .font(.body)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            ForEach(selection.orderedWebDomains, id: \.self) { token in
                Label(token)
                    .font(.body)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

extension PersistedSelection {
    var orderedApplications: [ApplicationToken] { Self.ordered(applicationTokens) }
    var orderedCategories: [ActivityCategoryToken] { Self.ordered(categoryTokens) }
    var orderedWebDomains: [WebDomainToken] { Self.ordered(webDomainTokens) }

    private static func ordered<T: Codable & Hashable>(_ values: Set<T>) -> [T] {
        values.sorted { lhs, rhs in
            let left = (try? JSONEncoder().encode(lhs)) ?? Data()
            let right = (try? JSONEncoder().encode(rhs)) ?? Data()
            return left.lexicographicallyPrecedes(right)
        }
    }
}
