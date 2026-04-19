import SwiftUI

@main
struct TahoePasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settingsManager = SettingsManager.shared

    var body: some Scene {
        Settings {
            SettingsView(settingsManager: settingsManager, historyViewModel: appDelegate.historyViewModel)
        }
        .commands {
            TahoePasteCommands(settingsManager: settingsManager, openSettings: appDelegate.openSettingsWindow)
        }
    }
}
