//
//  HomeView.swift
//  GeorgiaTechApp
//

import SwiftUI

/// The landing screen: the design handoff header and featured carousel,
/// followed by the existing ranked stack of campus bands.
///
/// The default order runs live/time-bound content above static with Get
/// Help last, but the order is the USER'S — `HomeBandStore` persists
/// whatever they drag it into. What doesn't change: a band with no data
/// renders nothing (no empty boxes), and every band is a preview that
/// pushes or jumps to its real screen; Home never owns a feature.
struct HomeView: View {
    @Binding var pendingCapacityID: Int?
    /// Home → Map tab with a place selected (bus stop, open venue).
    var onOpenMapPlace: (SearchCardModel) -> Void = { _ in }
    /// Home → Events tab.
    var onOpenEvents: () -> Void = {}
    /// Home → Map tab showing dining.
    var onOpenDining: () -> Void = {}

    @Environment(BusLiveManager.self) private var busLiveManager
    @AppStorage("homeBandOrder") private var bandOrderRaw = ""
    @State private var isShowingSettings = false
    @State private var isArrangingBands = false
    @State private var isShowingDates = false
    @State private var capacityFilterID: Int?
    @State private var isShowingCapacities = false
    @State private var eventToOpen: Event?

    // @Binding has no default-value syntax, so a custom init is needed to make
    // pendingCapacityID optional at call sites — without this, #Preview and any
    // HomeView() call without a binding would fail to compile.
    init(
        pendingCapacityID: Binding<Int?> = .constant(nil),
        onOpenMapPlace: @escaping (SearchCardModel) -> Void = { _ in },
        onOpenEvents: @escaping () -> Void = {},
        onOpenDining: @escaping () -> Void = {}
    ) {
        _pendingCapacityID = pendingCapacityID
        self.onOpenMapPlace = onOpenMapPlace
        self.onOpenEvents = onOpenEvents
        self.onOpenDining = onOpenDining
    }
    
    var body: some View {
        // The masthead's pattern runs under the status bar, so the scroll
        // view ignores the top inset and the masthead re-applies it to
        // its own content — read out here, where it's still reported.
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HomeMastheadView(
                        topInset: proxy.safeAreaInsets.top,
                        onOpenSettings: { isShowingSettings = true }
                    )
                    HomeFeaturedEventsBanner()
                    
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(HomeBandStore.decode(bandOrderRaw).filter { $0 != .gameDay }) { band in
                            self.band(band)
                        }
                        
                        arrangeButton
                    }
                    .padding(.bottom, 24)
                    .padding(.horizontal, 18)
                }
            }
            .ignoresSafeArea(edges: .top)
            .gtScreenBackground()
            .overlay(alignment: .top) {
                // Fixed status-bar scrim; the decorative pattern scrolls beneath it.
                LinearGradient(
                    colors: [Color.gtBackground, Color.gtBackground.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: proxy.safeAreaInsets.top + 10.1213)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isShowingSettings) {
                SettingsView()
                // Home hides the bar; pushed screens need theirs back.
                    .toolbar(.visible, for: .navigationBar)
            }
            .navigationDestination(isPresented: $isShowingDates) {
                GTDatesListView()
                    .toolbar(.visible, for: .navigationBar)
            }
            .navigationDestination(isPresented: $isShowingCapacities) {
                CapacitiesView(initialFilterID: capacityFilterID)
                    .toolbar(.visible, for: .navigationBar)
            }
            .sheet(isPresented: $isArrangingBands) {
                HomeBandsEditSheet(orderRaw: $bandOrderRaw)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .navigationDestination(item: $eventToOpen) { event in
                EventDetailView(event: event)
                    .toolbar(.visible, for: .navigationBar)
            }
            // The existing lower Home bands need live buses at a relaxed
            // cadence; the shared poller takes the fastest active interest
            // (see BusDataInterest), so this never duplicates the map's 6s loop.
            .onAppear {
                busLiveManager.setInterest(.home, active: true, interval: .seconds(30))
            }
            .onDisappear {
                busLiveManager.setInterest(.home, active: false)
            }
            .onChange(of: pendingCapacityID, initial: true) { _, id in
                guard let id else { return }
                capacityFilterID = id
                pendingCapacityID = nil
                // Dismiss first so SwiftUI tears down any existing CapacitiesView,
                // then re-present in the next cycle with the new capacityFilterID.
                // Setting false and true in the same synchronous block gets coalesced
                // to a no-op — the Task defers true to the next update cycle.
                isShowingCapacities = false
                Task { @MainActor in
                    isShowingCapacities = true
                }
            }
        }
    }

    /// Each band closes over Home's own state, so reordering is purely a
    /// question of what order this switch is called in.
    @ViewBuilder
    private func band(_ band: HomeBand) -> some View {
        switch band {
        case .gameDay:
            HomeGameDayBanner(onOpenEvent: { eventToOpen = $0 })
        case .rightNow:
            HomeRightNowSection(
                onOpenCapacity: { capacityID in
                    capacityFilterID = capacityID
                    isShowingCapacities = true
                }
            )
        case .openNow:
            HomeOpenNowCard(onOpenPlace: onOpenMapPlace)
        case .tonight:
            HomeTonightCard(onSeeAll: onOpenEvents)
        case .dates:
            HomeGTDatesCard(onSeeAll: { isShowingDates = true })
        case .quickLinks:
            HomeQuickLinksSection()
        case .getHelp:
            HomeGetHelpCard()
        }
    }

    /// Bottom of the scroll, the way the old app did it — an affordance
    /// at the end of the content it rearranges, not a header icon
    /// competing with the band titles.
    private var arrangeButton: some View {
        Button {
            isArrangingBands = true
        } label: {
            Label("Arrange Home", systemImage: "arrow.up.arrow.down")
                .font(.gtHeading6)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.gtSecondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .overlay {
                    Capsule().strokeBorder(Color.gtNavy.opacity(0.15), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .accessibilityHint("Reorder the sections of the home screen")
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(BusLiveManager())
    .environment(LocationManager())
}
