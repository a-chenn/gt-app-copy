# CLAUDE.md — Georgia Tech Campus App

Entry point for any Claude session working in this repo. Read this first, then follow the links for depth. This file stays short and points to `docs/` instead of repeating it.

**If something needed to do the task correctly isn't covered here or in `docs/`, ask the user. Do not guess at product intent, API behavior, or design direction and proceed as if it were confirmed.**

## Read these first

- [`docs/PRODUCT_SPEC.md`](docs/PRODUCT_SPEC.md): what the app does, for whom, what ships, what is planned and what is out of scope.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): folder structure, app shell, the unified location model, data flow, services, state management, guardrails.
- [`docs/DEVELOPMENT_PLAN.md`](docs/DEVELOPMENT_PLAN.md): current status, the timeline to the spring 2027 beta, known issues, partner dependencies.
- [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md): color tokens, type scale, shared components, accessibility.
- [`CONTRIBUTING.md`](CONTRIBUTING.md): branching, pull requests, naming conventions, testing.
- [`INSTALL.md`](INSTALL.md): local setup, `Config/Secrets.plist` and `Config/GoogleService-Info.plist`.

## Project status

The app is in its second semester of development (started January 2026). A first version is built. **New designs are arriving.** The color palette and type scale from the design spec are already in the app, and screen layouts will be rebuilt as designs land. Until then, fix bugs on existing screens but don't polish layouts that are about to change. The timeline runs to a spring 2027 beta and a fall 2027 campus-wide launch (see the development plan).

The backend is a separate repo, `Georgia-Tech-App-API`, in the same SGA organization. Its data feeds this app.

## Tech stack

- **Swift 6 toolchain**, project language mode `SWIFT_VERSION = 5.0` with `SWIFT_APPROACHABLE_CONCURRENCY = YES` (not strict Swift 6 mode). Xcode 26+, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`.
- **SwiftUI** exclusively. No UIKit (enforced by SwiftLint).
- **SwiftData** for local persistence: `@Model` types and a single `ModelContainer` configured once in `Core/App/`.
- **MapKit** and **CoreLocation** for the map, search and routing.
- **Firebase** (`FirebaseAuth`, `FirebaseAppCheck`) for sign-in, through Swift Package Manager only.
- **Swift Concurrency** (`async`/`await`, `TaskGroup`, actors). No `DispatchQueue`, `Thread`, `OperationQueue` or completion handlers.
- **Observation** (`@Observable`, `.environment`, `@Bindable`) for state. No `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject` or `@EnvironmentObject`.
- **Data:** the GT App API (base URL from `Config/Secrets.plist`'s `GTAPI` key, fetched through `GTDataService`) for dining, locations, appliances, capacity, events, news and dates, and the **TransLoc** bus relay for live buses. No other data source.
- **Tests and CI:** the Xcode project declares a `GeorgiaTechAppTests` target but there are no tests in the repo. There is no CI of any kind: no build, no test and no PR review workflow. Don't assume any exists when planning verification, and ask before adding a test strategy as part of an unrelated task.

## Non-negotiable rules

SwiftLint (`.swiftlint.yml`) enforces these. A failing lint means a rule was broken, not that the rule is optional.

- `@Observable`, `@State`, `@Environment`, `@Bindable` only for state.
- `async`/`await` and actors only for concurrency. Never `[weak self]` or `NotificationCenter` for state sharing.
- SwiftUI only: never `import UIKit`, never `UIScreen.main` (use `GeometryReader` or container sizing).
- Never `as!`.
- **Never redraw the GT mark.** The official lockups are vector assets in `Assets.xcassets` (`GTLogoOneLine`, `GTLogoHorizontal`, `GTLogoVertical`, `GTLogoExtended`). Use `GTLockup`.
- **Colors: only `Color.gt*`** from `Core/Utilities/Extensions/Color.swift`, which holds exactly the design spec's palette. Never a raw system color (`Color.red`, `Color.blue`), never a new hardcoded hex, never a new brand color without updating `Color.swift` and the spec.
- **Type: only `Font.gtHeading1`–`gtHeading6` and `Font.gtBody1`–`gtBody4`** from `Core/Utilities/Extensions/Font+GT.swift`. Never `.font(.headline)`, never a bare `Font.custom` (it drops Dynamic Type). No other fonts.
- Run `swiftlint` before considering any change done. Fix violations; don't disable rules unless the user confirms the rule is wrong.

Beyond lint, treat these as equally firm:

- Naming conventions in `CONTRIBUTING.md`: `View`, `VM`, `Service` suffixes, verb-first function names, boolean `is`/`has`/`should`/`can` prefixes.
- **Reuse the shared components** instead of re-deriving them: `GTSectionHeader`, `.gtCard()`, `GTFilterChip`, `GTLockup`, `GTDetailHero`, `GTBodyText`, `ExternalLinkButton`. See `docs/DESIGN_SYSTEM.md`.
- Every new interactive control gets an `accessibilityLabel` (and an `accessibilityHint` where useful) as it's built.
- Dark mode is checked, not assumed. The fixed-hex `gt*` colors don't adapt on their own. Only `gtPrimaryText`, `gtSecondaryText` and `gtBackground` fall back to iOS semantic colors in dark mode. Verify contrast in both appearances.

## What NOT to do

- **Don't build a data pipeline as fake or mocked "for now".** Every feature has a real data source, or it doesn't ship. The one exception is library room booking, which stays a visible "coming soon" placeholder because no backend exists. If you're about to hardcode sample data to make a screen look finished, stop and ask whether the real source should be wired up.
- **Don't build a type-specific service, pin view or detail view per map category.** No `PrinterService`, `VendingService` or per-type detail overlay. Everything placeable on the map goes through one `CampusLocation`-style model with a `category`, one pin renderer and one detail-card renderer.
- **Don't add a separate `Building` model.** `category` replaces it.
- **Don't build a second routing system for buses or any other mode.** Walking, biking, driving and bus are modes of one routing function (`RoutingVM` and `RouteManager`). Bus data feeds it.
- **The shell is a 3-tab `TabView`** (Home / Map / Events & News, in `Core/App/AppShellView.swift`) using the system tab bar. Don't add tabs, a sidebar or a second navigation shell without confirming with the user. The Map tab hides the tab bar and uses a floating Home button.
- **Every Home band is real data or absent.** No placeholder or empty boxes. Band order belongs to the user (`HomeBandStore`).
- **Don't build features that were deliberately cut:** user-authored alerts, class-schedule tracking, weather (it was built on WeatherKit and pulled because it needs a paid capability), or Siri and Spotlight App Intents. If asked to add one, confirm first.
- **Planned features need partner approval first.** BuzzCard, BuzzFunds and dining dollar balances, student printing and library booking all depend on OIT or another data owner. Don't start building one without checking with the user that access exists.
- **Don't add a custom spacing, shadow or corner-radius constants file.** Use native SwiftUI.
- **Don't build a generic `Router` or navigation framework.** A simple `enum Route` with `.navigationDestination(for:)` per feature is enough.
- **Don't spend time on SwiftData schema migration yet.** There are no real installs. Revisit before the beta.

## Architecture decisions

See `docs/ARCHITECTURE.md` for detail. The ones most likely to matter when writing code:

| Decision | Why |
|---|---|
| Feature-based folders (`Features/<Name>/{Views,ViewModels,Models,Services,Managers,State}`) | Keeps related code together as the app grows |
| One `CampusLocation` model with a `category`, no per-type split | Matches how a student thinks about the map, and avoids per-type sprawl |
| One routing function covering walk, bike, drive and bus | "Route me to X" is one call regardless of destination or mode |
| `GTDataService` plus per-domain extension files | Keeps networking centralized, so new domains are additive |
| Metadata-driven sync that skips unchanged domains | Cheap to build once and expensive to retrofit per domain |
| GT SSO with the code exchange on the backend | No SSO client secret ships in the app, and it was prioritized early |
| 3-tab shell with Home as the landing screen | A homepage serves daily campus use better than a map-first app |
| `LocationManager` and `BusLiveManager` owned by `AppShellView`, with interest-based polling (`BusDataInterest`) | Home's Next Bus card and the map share one TransLoc poller (map every 6 seconds, Home every 30) |
| Navy for structure, gold for selection, `gtDarkGold` instead of `gtGold` on light surfaces | Gold fails 3:1 contrast on light backgrounds |

## Quality standards

- SwiftLint clean on every change.
- Accessibility is part of done. A screen without labels on its icon-only controls isn't finished.
- Dark mode is checked in both appearances.
- Real data only. Real APIs only: the GT App API and TransLoc.
- Prefer native SwiftUI and system behavior unless there is a specific reason the system component can't do the job. The map's custom draggable sheet is the existing example.

## When you don't know something

Ask the user rather than assuming, especially for:

- Product or UX decisions not settled in `docs/PRODUCT_SPEC.md`.
- Whether a new map-item type fits the unified `category` model or genuinely needs something new.
- Brand color values. `Color.swift` is the only source of truth, so don't invent a color.
- Anything about real GT API credentials, endpoints or behavior you can't verify by reading the code.
- Test strategy. No tests exist yet, so ask before adding a test target or CI as part of an unrelated task.
- Anything about the new designs that isn't in the design spec or the code.
