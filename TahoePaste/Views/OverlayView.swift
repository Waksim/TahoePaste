import SwiftUI

struct OverlayView: View {
    @ObservedObject var viewModel: ClipboardHistoryViewModel
    @ObservedObject var settingsManager: SettingsManager
    private let searchBubbleTopPadding: CGFloat = 8
    private let searchBubbleBottomPadding: CGFloat = 6

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                overlayShape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.10, blue: 0.13).opacity(0.94),
                                Color(red: 0.13, green: 0.15, blue: 0.19).opacity(0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 1)
                    }

                VStack(spacing: 0) {
                    if viewModel.isSearchBubbleVisible {
                        searchBubble
                            .padding(.top, searchBubbleTopPadding)
                            .padding(.bottom, searchBubbleBottomPadding)
                    }

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
                                .frame(maxHeight: .infinity, alignment: .center)
                                .padding(.vertical, cardRowVerticalPadding)
                            }
                            .scrollClipDisabled()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .onAppear {
                                scrollToMostRecent(proxy, animated: false)
                            }
                            .onChange(of: viewModel.overlayPresentationID) {
                                scrollToMostRecent(proxy, animated: false)
                            }
                            .onChange(of: viewModel.searchQuery) {
                                scrollToMostRecent(proxy)
                            }
                            .onChange(of: viewModel.activeTagFilter) {
                                scrollToMostRecent(proxy)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 0)
                .padding(.vertical, 0)
            }
            .overlay(alignment: .topTrailing) {
                overlayControls(proxy: proxy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.locale, settingsManager.appLanguage.locale)
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
                .foregroundStyle(.white)

            Text(L10n.tr("overlay.empty_subtitle"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.68))
                .frame(maxWidth: 360, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var noResultsState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr("overlay.no_matches_title"))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text(L10n.tr("overlay.no_matches_subtitle"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.68))
                .lineLimit(2)
                .frame(maxWidth: 420, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var searchBubble: some View {
        HStack(spacing: 10) {
            Text(viewModel.searchDisplayText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(viewModel.isSearching ? 0.92 : 0.64))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Button(action: {
                viewModel.clearTransientState()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.52))
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
                .fill(Color(red: 0.16, green: 0.18, blue: 0.22).opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .center)
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
        .padding(.top, 5)
        .padding(.trailing, 10)
    }

    private func toolbarButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(red: 0.72, green: 0.75, blue: 0.80).opacity(0.70))
                .frame(width: 18, height: 18)
                .padding(4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var cardRowVerticalPadding: CGFloat {
        let basePadding: CGFloat

        switch settingsManager.cardSizePreset {
        case .compact:
            basePadding = 8
        case .comfortable:
            basePadding = 12
        case .large:
            basePadding = 16
        }

        return viewModel.isSearchUIVisible ? max(basePadding - 4, 6) : basePadding
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
