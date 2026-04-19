import SwiftUI

struct MenuBarIconView: View {
    var body: some View {
        Image("MenuBarIcon")
            .renderingMode(.template)
            .interpolation(.high)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 18, height: 14)
            .accessibilityLabel(L10n.tr("common.tahoepaste"))
    }
}
