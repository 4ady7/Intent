import Combine
import FamilyControls
import Foundation

@MainActor
final class ScreenTimeAuthorizationService: ScreenTimeAuthorizing {
    private(set) var state: ScreenTimeAuthorizationState = .notDetermined
    private var ticket: AnyCancellable?

    init() {
        refresh()
        ticket = AuthorizationCenter.shared.$authorizationStatus.sink { [weak self] status in
            Task { @MainActor in
                self?.apply(status)
            }
        }
    }

    func refresh() {
        apply(AuthorizationCenter.shared.authorizationStatus)
    }

    func requestAccess() async throws {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refresh()
            switch state {
            case .approved:
                return
            case .denied:
                throw FocusError.notAuthorized
            case .notDetermined, .unavailable:
                throw FocusError.authorizationUnavailable
            }
        } catch let error as FocusError {
            throw error
        } catch {
            refresh()
            FocusLog.session.error("Authorization failed: \(error.localizedDescription, privacy: .public)")
            throw Self.map(error)
        }
    }

    private func apply(_ status: AuthorizationStatus) {
        switch status {
        case .approved:
            state = .approved
        case .denied:
            state = .denied
        case .notDetermined:
            state = .notDetermined
        @unknown default:
            state = .unavailable
        }
    }

    static func map(_ error: Error) -> FocusError {
        guard let family = error as? FamilyControlsError else {
            return .authorizationUnavailable
        }
        switch family {
        case .authorizationCanceled:
            return .notAuthorized
        case .restricted, .unavailable, .invalidAccountType, .invalidArgument, .authenticationMethodUnavailable:
            return .authorizationUnavailable
        case .networkError:
            return .scheduleFailed("Screen Time authorization needs a network connection. Try again.")
        case .authorizationConflict:
            return .scheduleFailed("Another Screen Time authorization is already in progress.")
        @unknown default:
            return .authorizationUnavailable
        }
    }
}
