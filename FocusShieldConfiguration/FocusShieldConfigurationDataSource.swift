import ManagedSettings
import ManagedSettingsUI
import UIKit

class FocusShieldConfigurationDataSource: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        let now = Date()
        var endDate: Date?
        if let store = try? FocusStore.live(),
           let session = try? store.loadActive(),
           session.phase == .active {
            endDate = session.endDate
            if now < session.endDate {
                try? store.recordShieldPresentation(at: now)
            }
        }

        let ink = UIColor(red: 0.09, green: 0.11, blue: 0.11, alpha: 1)
        let mist = UIColor(red: 0.86, green: 0.91, blue: 0.88, alpha: 1)
        let icon = UIImage(
            systemName: "moon.stars",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)
        )
        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: ink,
            icon: icon,
            title: ShieldConfiguration.Label(text: ShieldCopy.title, color: .white),
            subtitle: ShieldConfiguration.Label(
                text: ShieldCopy.subtitle(endDate: endDate, now: now),
                color: UIColor(white: 0.90, alpha: 1)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: ShieldCopy.button, color: ink),
            primaryButtonBackgroundColor: mist
        )
    }
}
