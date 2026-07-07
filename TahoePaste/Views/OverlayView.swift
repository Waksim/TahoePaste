import SwiftUI

struct OverlayView: View {
    // OverlayWindowController derives the window height from these: top bar
    // plus one card row plus the bottom inset. The bar keeps 5 pt above and
    // below its 26 pt icons, and bottomInset mirrors that gap under the cards.
    static let topBarHeight: CGFloat = 36
    static let bottomInset: CGFloat = 5

    @ObservedObject var viewModel: ClipboardHistoryViewModel
    @ObservedObject var settingsManager: SettingsManager

    private var themePalette: SettingsManager.ThemePalette {
        settingsManager.themePalette
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                overlayShape
                    .fill(
                        LinearGradient(
                            colors: [
                                themePalette.overlayGradientTop,
                                themePalette.overlayGradientBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(themePalette.overlayEdgeHighlight)
                            .frame(height: 1)
                    }

                VStack(spacing: 0) {
                    topBar(proxy: proxy)

                    Group {
                        if viewModel.visibleItems.isEmpty {
                            if viewModel.isSearching {
                                noResultsState
                            } else {
                                emptyState
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(alignment: .center, spacing: 16) {
                                    ForEach(viewModel.visibleItems) { item in
                                        ClipboardCardView(
                                            item: item,
                                            image: viewModel.image(for: item),
                                            settingsManager: settingsManager,
                                            activeTagFilter: viewModel.activeTagFilter
                                        ) {
                                            viewModel.select(item)
                                        } tagAction: { tag in
                                            viewModel.toggleTagFilter(tag)
                                        } deleteAction: {
                                            viewModel.delete(item)
                                        }
                                        .id(item.id)
                                    }
                                }
                                .frame(maxHeight: .infinity, alignment: .top)
                            }
                            .contentMargins(.horizontal, 16, for: .scrollContent)
                            .scrollClipDisabled()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .onAppear {
                                scrollToMostRecent(proxy, animated: false)
                            }
                            .onChange(of: viewModel.overlayPresentationID) {
                                scrollToMostRecent(proxy, animated: false)
                            }
                            .onChange(of: viewModel.visibleItems.first?.id) {
                                scrollToMostRecent(proxy)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 0)
                .padding(.vertical, 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.locale, settingsManager.appLanguage.locale)
        .preferredColorScheme(settingsManager.preferredColorScheme)
    }

    private var overlayShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: 0,
                bottomLeading: CGFloat(settingsManager.cornerRadiusIntensity),
                bottomTrailing: CGFloat(settingsManager.cornerRadiusIntensity),
                topTrailing: 0
            ),
            style: .continuous
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr("overlay.empty_title"))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(themePalette.overlayPrimaryText)

            Text(L10n.tr("overlay.empty_subtitle"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(themePalette.overlaySecondaryText.opacity(0.92))
                .frame(maxWidth: 360, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var noResultsState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr("overlay.no_matches_title"))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(themePalette.overlayPrimaryText)

            Text(L10n.tr("overlay.no_matches_subtitle"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(themePalette.overlaySecondaryText.opacity(0.92))
                .lineLimit(2)
                .frame(maxWidth: 420, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func topBar(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 12) {
            if viewModel.isSearchBubbleVisible {
                searchBubble
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Spacer(minLength: 0)
            }

            overlayControls(proxy: proxy)
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .frame(height: Self.topBarHeight)
    }

    private var searchBubble: some View {
        HStack(spacing: 10) {
            Text(viewModel.searchDisplayText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    themePalette.overlayPrimaryText.opacity(viewModel.isSearching ? 0.92 : 0.64)
                )
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Button(action: {
                viewModel.clearTransientState()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(themePalette.overlaySecondaryText.opacity(0.74))
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(themePalette.overlayBubbleFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(themePalette.overlayBubbleBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .frame(maxWidth: 480)
    }

    private func overlayControls(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            toolbarButton(systemName: "gearshape") {
                viewModel.openSettings()
            }

            toolbarButton(systemName: "magnifyingglass") {
                viewModel.beginSearch()
            }

            toolbarButton(systemName: "arrow.left.to.line") {
                scrollToMostRecent(proxy)
            }
        }
    }

    private func toolbarButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(themePalette.overlayToolbarIcon.opacity(0.78))
                .frame(width: 18, height: 18)
                .padding(4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func scrollToMostRecent(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard let newestItemID = viewModel.visibleItems.first?.id else {
            return
        }

        let scrollAction = {
            proxy.scrollTo(newestItemID, anchor: .leading)
        }

        if animated {
            withAnimation(.snappy(duration: 0.18)) {
                scrollAction()
            }
        } else {
            scrollAction()
        }
    }
}
