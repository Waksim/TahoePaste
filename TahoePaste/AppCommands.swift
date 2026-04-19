import SwiftUI

struct TahoePasteCommands: Commands {
    @ObservedObject var settingsManager: SettingsManager
    let openSettings: () -> Void

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(L10n.tr("common.settings_ellipsis")) {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
