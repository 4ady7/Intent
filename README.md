# Focus

A native iOS app that blocks the apps, categories, and websites you choose for a set time. Restrictions use Apple's Screen Time frameworks. There is no account, server, or analytics.

Requires iOS 17 or later, on iPhone. The Simulator can build the interface, but it cannot apply real shields.

## Run it on a device

1. Install an iOS Simulator runtime in Xcode → Settings → Platforms. This Xcode's asset compiler looks for one even when the destination is a physical iPhone. This Mac currently has the iOS 18.2 SDK and no simulator runtime.
2. Open `Focus.xcodeproj` in Xcode (not only the Command Line Tools). If `xcodebuild` cannot find the iOS SDK, prefix it with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
3. Set your team in `Config/Shared.xcconfig`:

   ```
   FOCUS_BUNDLE_ID = com.yourname.Focus
   FOCUS_APP_GROUP = group.com.yourname.Focus
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   ```

   Change all three together. The app, the three extensions, and the test bundle derive their identifiers from `FOCUS_BUNDLE_ID`.
4. In the Apple Developer portal, register the app ID and each extension ID, and create the App Group. Enable Family Controls and the App Group on all four IDs:

   - `com.yourname.Focus`
   - `com.yourname.Focus.Monitor`
   - `com.yourname.Focus.ShieldConfiguration`
   - `com.yourname.Focus.ShieldAction`
   - App Group `group.com.yourname.Focus`

5. In Xcode, confirm every target uses `Config/Focus.entitlements` and your team. Signing is Automatic.
6. Run on a physical iPhone that is signed into iCloud as the device owner, with Screen Time available. Individual authorization uses Face ID or the device passcode. A child account, a managed device, or Screen Time restrictions can make authorization unavailable. Focus does not ask again on its own after you decline.
7. If access was denied, Settings → Screen Time → Apps With Screen Time Access, then return to Focus and tap Allow Screen Time Access.

Development builds can use Family Controls once the capability is on the App ID. TestFlight and the App Store need a separate Family Controls distribution approval for the app and each extension: [Requesting the Family Controls entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement).

## What a session does

Choose distractions in Apple's picker, choose a duration, and start. Focus writes shields to a Managed Settings store named `focus`, then schedules a one-shot Device Activity interval. The countdown is the session's absolute end time minus the current time. When the interval ends, the monitor extension records the session and clears that store. Opening Focus after the end time does the same if the callback has not arrived.

Ending early asks for confirmation. Only one session runs at a time.

Presets are Study, Deep Work, Reading, Coding, Work, and Custom. Each remembers its selection and duration. Built-in names stay fixed. Custom can be renamed from the session name.

## Project

| Target | Role |
| --- | --- |
| Focus | SwiftUI app |
| FocusMonitor | `DeviceActivityMonitor` — reapply on start, clear and record on end |
| FocusShieldConfiguration | Shield copy and colors |
| FocusShieldAction | Close button |
| FocusTests | Logic, persistence, and session service tests |

Shared session code lives in `Shared/` and is compiled into the app and the tests. The monitor and shield configuration compile the subset they need. `scripts/generate_xcodeproj.py` regenerates the Xcode project. After adding a Swift file, either run that script or add the file to the target by hand.

## Privacy

Selections are Apple's opaque tokens. Focus stores them, with session history, in an App Group container as JSON. It does not use UserDefaults. If the App Group container is missing, history can fall back to local app storage, but Focus will not start a blocking session.

## Limits that come from Apple

- Sessions shorter than 15 minutes cannot be scheduled. The shortest choice is 15 minutes.
- A resumed session with less than 15 minutes left is given a 15-minute safety window. If Focus stays closed, shields can remain until that window ends. If Focus is open, it clears them at the real end time.
- The shield can close the blocked app. There is no API to open Focus from that screen. The button says Close.
- Device Activity follows the system clock. Changing the clock moves the session.
- The interruption count is the number of shield presentations, debounced by 30 seconds. It is not a precise count of how often you left the session.
- Family Controls distribution is a managed capability. A development profile is not enough for TestFlight.
