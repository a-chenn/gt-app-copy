# Bus arrival-times API

Use [`BusLiveManager`](../GeorgiaTechApp/Features/Map/Managers/BusLiveManager.swift) for automatically refreshed arrival times in SwiftUI. It is the app's `@Observable`, `@MainActor` bus-data interface. `AppShellView` already owns and injects one shared instance.

Predictions use historical corrections when available and fall back to TransLoc. These APIs are internal to the GeorgiaTechApp module.

## Quick start

Read predictions using a stop's **`routeStopID`**. A physical stop serving several routes has a different route-stop ID for each route. Resolve the stop from the selected `BusRoute.stops`; do not use `stopAddressID` for this lookup.

```swift
import SwiftUI

struct StopArrivalTimesView: View {
    @Environment(BusLiveManager.self) private var busLiveManager
    let stop: BusStop // A stop belonging to the selected route.

    private var arrivals: [BusStopEstimate] {
        (busLiveManager.stopEstimates[stop.routeStopID] ?? [])
            .filter(\.isOnRoute)
            .sorted { $0.secondsToStop < $1.secondsToStop }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stop.name).font(.gtHeading4)

            if busLiveManager.isLoading && arrivals.isEmpty {
                ProgressView("Loading arrivals…")
            } else if arrivals.isEmpty {
                Text("No arrival predictions available.")
                    .font(.gtBody2)
            }

            ForEach(arrivals, id: \.vehicleID) { estimate in
                HStack {
                    Text(estimate.arrival?.displayName
                         ?? "Vehicle \(estimate.vehicleID)")
                    Spacer()
                    Text(estimate.arrival?.source == .arriving
                         ? "Arriving"
                         : BusArrivals.minutesText(estimate.secondsToStop))
                }
                .font(.gtBody2)
                .accessibilityElement(children: .combine)
            }
        }
        .foregroundStyle(Color.gtPrimaryText)
    }
}
```

This lists every available next bus prediction for that route stop. There is one prediction per vehicle, not every future loop arrival. Observation updates the view when the manager publishes new estimates.

## Polling

```swift
func setInterest(
    _ interest: BusDataInterest,
    active: Bool,
    interval: Duration = .seconds(6)
)
```

Call from the feature that owns the polling lifecycle:

```swift
// Map: refresh immediately, then wait six seconds between refreshes.
busLiveManager.setInterest(.map, active: true)

// Home uses a slower interval.
busLiveManager.setInterest(.home, active: true, interval: .seconds(30))

// Release this feature's interest when it disappears.
busLiveManager.setInterest(.map, active: false)
```

- The fastest active interval wins. Polling stops when no interests remain.
- Existing Map and Home screens already manage their interests. Child stop cards should only read data.
- Each interest is one named slot, not a reference-counted subscription. Do not let multiple children independently register/release `.map`.
- Stopping retains the last snapshot. Re-registering an unchanged active interest does not force a refresh.
- There is no public `BusLiveManager.refresh()`, `selectRoute()` or `selectStop()`. Route/stop selection belongs to your presentation state.

## Observable state

All properties below are externally read-only.

| Property | Type | Meaning |
|---|---|---|
| `stopEstimates` | `[Int: [BusStopEstimate]]` | Predictions keyed by `routeStopID` |
| `isLoading` | `Bool` | A manager refresh is in progress; existing results may remain visible |
| `error` | `String?` | Last top-level refresh failure |
| `warnings` | `[String]` | Partial failures or fallback diagnostics |
| `updatedAt` | `Date?` | Last successful telemetry snapshot's completion time; not a per-stop freshness guarantee |
| `buses` | `[BusLive]` | Optional live metadata for rows, matched using `vehicleID` |

An empty list does not prove there is no scheduled service. Inspect loading, errors and warnings before choosing empty-state wording. After failures, old estimates can remain until a later refresh checks their age; there is no independent expiration timer.

In `LiveBusPopover`, read `bus.dwell` from the supplied `BusLive`. Display `dwell.stopName` and `dwell.seconds` when the value is present and `Date.now < dwell.expiresAt`.

## Arrival fields

[`BusStopEstimate`](../GeorgiaTechApp/Core/Models/UI%20Models/BusStopEstimate.swift) provides:

| Field | Type | Meaning |
|---|---|---|
| `routeStopID` | `Int` | Destination stop on a particular route |
| `vehicleID` | `Int` | Internal bus identity; suitable as a row ID within one stop's list |
| `secondsToStop` | `Int` | Predicted arrival seconds at calculation time |
| `stopOrder` | `Int` | Stop's position in the route sequence |
| `isOnRoute` | `Bool` | Arrival eligibility |
| `arrival` | `Arrival?` | Rich prediction metadata, when available |

Useful `Arrival` fields:

| Field | Meaning |
|---|---|
| `displayName` | Fleet label, otherwise internal vehicle identity |
| `predictedArrival` | Final predicted arrival date |
| `translocArrival` | Original vendor arrival date |
| `remainingSeconds` / `translocSeconds` | Final/original countdown relative to the snapshot's fetch time |
| `source` | `.hybrid`, `.transloc` or `.arriving` |
| `anchorStopName`, `stopsAway` | Prediction context when available |
| `appliedOffsetSeconds` | Actual correction applied |

Times describe **arrival**, not departure after dwelling at the stop. Countdown values are fixed between refreshes. For a ticking display, derive remaining time from `predictedArrival` and the current display time.

`BusArrivals.minutesText(_:)` displays at least `1 min`, including for zero seconds. Check `.arriving` first if the UI should display “Arriving.”

## One-shot requests

### Full shared snapshot

```swift
let snapshot = try await BusTelemetryService.shared.refresh()
let estimates = snapshot.stopEstimates?[stop.routeStopID] ?? []
```

[`refresh()`](../GeorgiaTechApp/Features/Map/Services/BusPrediction/BusTelemetryService.swift) returns a `BusTelemetrySnapshot` containing `buses`, optional `stopEstimates`, `updatedAt` and `warnings`. Concurrent callers share in-flight work.

A nil estimates dictionary means arrival data was unavailable for this refresh. A covered stop with an empty array has no usable predictions in the successful response. Calling the service directly **does not publish into `BusLiveManager`**; the caller receives a snapshot.

### Single route and stop

```swift
let snapshot = try await BusArrivalService.shared.fetchSnapshot(
    for: String(stop.routeStopID),
    settings: PredictionSettings(routeID: String(route.routeID))
)
let arrivals = snapshot.arrivals // [Arrival], soonest first
```

[`fetchSnapshot(for:settings:requestedAt:)`](../GeorgiaTechApp/Features/Map/Services/BusPrediction/BusArrivalService.swift) is an independent request. It does not poll, join the full telemetry refresh, or update the manager. It throws for invalid bundled route/stop IDs and unusable required inputs; successful responses can include warnings.

- Pass the selected route explicitly. This API uses string IDs and bundled route definitions.
- Historical means come only from the matching 120-minute New York time bucket. Any valid matching bucket is used regardless of sample count or service-date coverage. Missing bucket data still uses TransLoc. The separate two-hour route/time offsets still apply to hybrid predictions. There is no all-day averaging option.
- Optional `requestedAt: Date?` anchors offset selection; it defaults to request-start time.
- The result contains route/stop IDs and names, `[Arrival]`, `updatedAt` and `warnings`.
- A selection-driven caller must manage loading/errors and ignore results from superseded selections.

Prefer the shared manager for normal Map/Home UI. Use one-shot APIs when a caller specifically needs an awaited result; do not request arrivals separately for every row.
