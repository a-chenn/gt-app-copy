# Architecture

How the app is organized and why. For what it does, see [PRODUCT_SPEC.md](PRODUCT_SPEC.md). Naming conventions are in [CONTRIBUTING.md](../CONTRIBUTING.md).

## Folder structure

The app is organized by feature. Code for one area lives together.

```
GeorgiaTechApp/
  Core/
    App/             App entry point, root view, tab shell, ModelContainer setup
    Components/      Shared UI: GTSectionHeader, GTFilterChip, GTLockup, GTDetailHero,
                     GTBodyText, ExternalLinkButton
    Models/
      JSON/          Decodable DTOs matching the backend's responses
      SwiftData/     @Model persistence entities shared across features
      UI Models/     Small view-ready types for live data (BusLive, BusStopEstimate)
    Services/
      GTData/        GTDataService plus one extension file per data domain
      AuthService.swift, ConfigService.swift
    Utilities/       Pure helpers (DiningHours, BusArrivals, TransitPlanner, ...)
      Extensions/    Color, Font, and framework extensions
  Features/
    Auth/  Capacities/  Events/  Home/  Map/  Search/  Settings/
      Views/  ViewModels/  Models/  Services/  Managers/  State/   (only what a feature needs)
  Resources/         Assets, bundled fonts
docs/
```

New functionality gets its own `Features/<Name>` folder in this shape. Don't add top-level folders under `Core/` for feature-specific code.

## The app shell

The app is a 3-tab `TabView` (`Core/App/AppShellView.swift`): **Home**, **Map**, and **Events & News**. Home is the landing screen. It uses the system tab bar, not a custom one, for Liquid Glass and correct safe-area behavior. Don't add tabs or a second navigation shell without agreeing it with the product manager.

- `RootView` holds the sign-in gate and the startup sync.
- `AppShellView` owns the shared live managers, `LocationManager` and `BusLiveManager`, and passes them down through the environment.
- **The Map tab hides the tab bar.** Its search sheet is always presented (a native sheet with detents at 72pt, 400pt and large), so it would cover the bar anyway. A floating Home button on the map is the way back.
- `Features/Home/` holds the Home bands. Each band shows real data or renders nothing, and each previews a real screen. Get Help is always last. Band order is user-editable (`HomeBandStore`).

## The unified location model

The most important modeling decision: **everything placeable on the map is one kind of thing with a `category`.**

Persistence stays per backend domain (`CampusLocation`, `Restaurant`, `Appliance`, `BusStop`). Each converts to one presentation model, `SearchCardModel`, which carries a `LocationCategory` (`.building`, `.dining`, `.printer`, `.microwave`, `.vending`, `.parking`, `.busStop`, and so on) through a `toSearchCard()` extension. Category-specific data such as menus and departures is looked up by id inside the one detail card.

Rendering follows the same rule: **one pin view and one detail card**, each branching on `category`. Don't build a view or service per place type. If a new type doesn't fit the model, reconsider the model instead of adding a parallel view. There is deliberately no separate `Building` model.

**Live buses are not part of this model.** A bus stop is a place and gets the shared detail card with a Departures section. A bus's live position and capacity right now is temporary telemetry. It is never stored as a location and doesn't get the detail card. It draws as its own heading-rotated marker and opens a small transient popover.

**Map points of interest.** MapKit's default POIs stay visible on the resting map and hide only while the app's own pins are showing, so Apple's data never competes with GT's.

## Data flow

```
GT App API  /  TransLoc bus relay
      │  async/await, URLSession
      ▼
GTDataService  (+Dining, +Events, +News, +CampusLocations, +Appliances,
      │         +BuildingCapacity, +Dates, +Transportation, ...)
      │  metadata check: skip what hasn't changed
      ▼
SwiftData  (single ModelContainer, set up once in Core/App)
      │  @Query or explicit fetch
      ▼
@Observable ViewModels  (MapVM, RoutingVM, SearchVM, EventsVM, ...)
      ▼
SwiftUI Views
```

- **Backend.** The GT App API (its own repo, `Georgia-Tech-App-API`) collects public GT data into a database and serves it. The app's base URL is the `GTAPI` key in `Config/Secrets.plist`. Live bus data comes straight from TransLoc through GT's relay (`bus.gatech.edu/Services/JSONPRelay.svc`) and doesn't touch our backend. There is no other data source, and no GT Places API.
- **Networking.** `GTDataService` has a generic `fetch<T: Decodable>(_:)` and `fetchAbsolute` for the bus domain. New domains are new `GTDataService+<Domain>.swift` extension files, not new service classes. `AuthService` is the deliberate exception because the SSO flow isn't campus-data CRUD.
- **Sync.** Once per launch, after sign-in, `syncAll` fetches `metadata/`, compares each domain's server timestamp to the stored `Metadata` row, and downloads only domains that changed. A domain's timestamp is saved only after its sync succeeds, so a failure retries next launch. Missing timestamps in the metadata response are optional on purpose: a missing one means "refresh", and it never fails the whole decode. Bus routes are the exception and refresh every launch, since `isRunning` changes through the day.
- **Upsert vs replace.** Prefer id-based upsert (as `CampusLocation`, events and news do) over delete-all-and-reinsert (`ModelContext.replaceExisting`) for entities with relationships or frequent refreshes, because replace-all causes flicker. Dining still uses replace-all because of its deep menu graph.
- **Offline.** Data is cached on the device in SwiftData and stays until the next successful sync replaces it. If a sync fails, the cache stays.
- **Auth.** Core data fetches don't need a Firebase token. Only `ConfigService`, currently unused, is auth-gated.

### Sign-in

GT SSO uses `ASWebAuthenticationSession` (system browser, so the app never sees the password) with a client-generated `state` checked against the callback. The code exchange happens on the backend, so no SSO client secret ships in the app. The backend returns a Firebase token and Firebase Authentication holds the account. Guests sign in anonymously through Firebase.

## Services and managers

| Name | Location | Responsibility |
|---|---|---|
| `GTDataService` | `Core/Services/GTData/` | Networking and sync for all GT backend and TransLoc data |
| `AuthService` | `Core/Services/` | GT SSO flow and Firebase sign-in and sign-out |
| `ConfigService` | `Core/Services/` | Auth-gated remote config (unused for now) |
| `LocationManager` | `Features/Map/Managers/` | Wraps `CLLocationManager` |
| `RouteManager` | `Features/Map/Managers/` | Route planning, the committed route, and live navigation (steps, progress, reroute, arrival) |
| `BusLiveManager` | `Features/Map/Managers/` | Polls TransLoc for live vehicles, capacities and arrival estimates |
| `CampusSearchService` | `Features/Search/Services/` | Filters cached campus data by category and text |
| `ExternalSearchService` | `Features/Search/Services/` | Wraps `MKLocalSearch` for free-text search |
| `RecentService`, `FavoritesService` | `Features/Search/Services/` | SwiftData storage for recents, saved places and favorite dishes |
| `AuthManager` | `Features/Auth/Managers/` | Observable sign-in state for the UI |

`BusLiveManager` polls by interest (`BusDataInterest`): the map asks for 6-second updates while buses are visible, Home's Next Bus card asks for 30 seconds while on screen, and the poller runs at the fastest active interest and stops when none remain. `BusTelemetryService` in `Features/Map/Services/BusPrediction/` coordinates one shared refresh for this poller and on-demand transit planning; concurrent consumers join the same in-flight task. All network access still goes through `GTDataService+Transportation`. Vehicle points and capacities are combined with batched `GetStopArrivalTimes` and `GetVehicleRouteStopEstimates` responses. Routes with schedule and polylines remain in SwiftData, synced each launch; live route definitions are cached in memory for five minutes. Live snapshots are never persisted.

Arrival prediction logic is imported from `gt-app-buses`: use an eligible upcoming stop as the anchor, add historical journey time, and apply the route/distance/time offset once. Historical averages use 120-minute New York time buckets regardless of sample count or service-date coverage. Only `bucketed.csv` tables are loaded; missing buckets fall back to TransLoc, with no all-day mean. The separate two-hour route/distance offset schedule remains in use. Missing, ambiguous or changed-route history falls back to the original TransLoc prediction. The bundled `Resources/live-arrival-times/` folder contains the route definitions, per-route average tables and offset schedule; raw trip logs are not shipped. `BusStopEstimate` keeps the original/adjusted prediction metadata alongside its existing seconds interface. Successful empty arrivals clear old results; failures hold the previous arrivals for at most 30 seconds when the next refresh checks freshness.

Live buses use the integer `Heading` supplied by TransLoc directly to rotate the original directional marker. There is no inferred-heading service, stopped-bus fallback or camera-heading adjustment. Partial failures remain available as manager warnings; loading state, completion time and errors are observable without adding new UI.

## Routing

Walking, biking, driving and bus are modes of one routing function (`RoutingVM.calculateAllModes()` and `RouteManager`), computed in parallel with a `TaskGroup`. Bus-specific data (stops, live vehicles, arrival estimates) feeds that function. It doesn't get its own navigation stack. "Route me to X" is one call regardless of destination or mode.

Pure routing math lives in `Core/Utilities/`:

- `RouteNavigation` handles step extraction, projection onto the route, and off-route and arrival tests.
- `BusArrivals` and `TransitPlanner` compose walk, wait, ride and walk into a transit plan. Arrival times use the same shared hybrid predictions and TransLoc fallback as Home and Map. If walking is faster, the planner says so instead of recommending the bus.

Planning and active navigation render inside the main sheet, never in a second sheet.

## State management

- `@Observable` throughout. Never `ObservableObject`, `@Published` or `@EnvironmentObject`.
- `@State` for local view state and for owning an `@Observable` object.
- `.environment(...)` and `@Environment(Type.self)` for feature-scoped shared state.
- `@Bindable` for two-way bindings to an `@Observable`.
- `@Query` in views is fine for simple reads. New features should read through their ViewModel.
- Small view-local coordination state (`MapSheetState`) is fine inside its feature. Don't turn it into an app-wide container.

## Guardrails

- No generic `Router` framework. A simple `enum Route` with `.navigationDestination(for:)` is enough when a feature needs push navigation.
- No per-category services (`PrinterService`, `VendingService`, ...). One extension covers all appliance types.
- No custom spacing, shadow or corner-radius constants file. Use native SwiftUI.
- No fake data for features that lack a real source. Library booking is a labeled placeholder.
- No SwiftData schema migration work for now, since there are no real installs yet. Revisit before the beta puts data on real devices.

## Code quality gate

SwiftLint (`.swiftlint.yml`) enforces most of the above: no `ObservableObject` family, no `DispatchQueue`/`Thread`/`OperationQueue`, no UIKit imports, no force casts, no hardcoded system colors. Run `swiftlint` before every commit and extend the config as new conventions appear.
