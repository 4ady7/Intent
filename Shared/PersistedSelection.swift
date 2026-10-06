import Foundation
import ManagedSettings

struct PersistedSelection: Equatable {
    var applicationTokens: Set<ApplicationToken>
    var categoryTokens: Set<ActivityCategoryToken>
    var webDomainTokens: Set<WebDomainToken>
    var includeEntireCategory: Bool

    #if DEBUG
    var testDistractionCount: Int?
    #endif

    init(
        applicationTokens: Set<ApplicationToken> = [],
        categoryTokens: Set<ActivityCategoryToken> = [],
        webDomainTokens: Set<WebDomainToken> = [],
        includeEntireCategory: Bool = true
    ) {
        self.applicationTokens = applicationTokens
        self.categoryTokens = categoryTokens
        self.webDomainTokens = webDomainTokens
        self.includeEntireCategory = includeEntireCategory
    }

    var distractionCount: Int {
        #if DEBUG
        if let testDistractionCount {
            return testDistractionCount
        }
        #endif
        return applicationTokens.count + categoryTokens.count + webDomainTokens.count
    }

    var hasSelection: Bool {
        distractionCount > 0
    }

    #if DEBUG
    init(testDistractionCount: Int) {
        self.init()
        self.testDistractionCount = testDistractionCount
    }
    #endif
}

extension PersistedSelection: Codable {
    private enum CodingKeys: String, CodingKey {
        case applicationTokens
        case categoryTokens
        case webDomainTokens
        case includeEntireCategory
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(applicationTokens, forKey: .applicationTokens)
        try container.encode(categoryTokens, forKey: .categoryTokens)
        try container.encode(webDomainTokens, forKey: .webDomainTokens)
        try container.encode(includeEntireCategory, forKey: .includeEntireCategory)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        applicationTokens = try container.decode(Set<ApplicationToken>.self, forKey: .applicationTokens)
        categoryTokens = try container.decode(Set<ActivityCategoryToken>.self, forKey: .categoryTokens)
        webDomainTokens = try container.decode(Set<WebDomainToken>.self, forKey: .webDomainTokens)
        includeEntireCategory = try container.decodeIfPresent(Bool.self, forKey: .includeEntireCategory) ?? true
    }
}
