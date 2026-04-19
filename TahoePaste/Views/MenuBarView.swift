import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: ClipboardHistoryViewModel
    @ObservedObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(settingsManager.monitoringStatusText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                Text(viewModel.savedItemsStatusLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button {
                viewModel.showOverlay()
            } label: {
                Label(L10n.tr("common.show_clipboard"), systemImage: "rectangle.bottomthird.inset.filled")
            }

            Button {
                viewModel.openSettings()
            } label: {
                Label(L10n.tr("common.settings"), systemImage: "gearshape")
            }

            Button(role: .destructive) {
                viewModel.quit()
            } label: {
                Label(L10n.tr("common.quit_tahoepaste"), systemImage: "power")
            }
        }
        .padding(14)
        .frame(width: 250)
    }
}
