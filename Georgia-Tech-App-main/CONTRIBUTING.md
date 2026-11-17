# Contributing

How we work on the app: branching, pull requests, naming conventions and testing. For how the code is organized, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). For setup, see [INSTALL.md](INSTALL.md).

## Bundle identifier

Each developer uses their own bundle identifier so signing doesn't collide. Keep it consistent across your builds.

- Format: `com.<firstname><lastname>.GTApp`
- Example: `com.braydenhuguenard.GTApp`

To change it in Xcode: select the `GeorgiaTechApp` project, then the `GeorgiaTechApp` target, then Signing & Capabilities. **Do not use someone else's bundle identifier.**

## Branching and pull requests

- **Branch name:** `FirstNameLastName - Ticket Objective`
- Open a pull request using `.github/PULL_REQUEST_TEMPLATE.md`.
- Before requesting review, run `swiftlint` and fix every violation. Don't disable a rule to get a change through; raise it with the tech lead if you think the rule is wrong.
- Include screenshots for any UI change.

## Code rules

SwiftLint (`.swiftlint.yml`) enforces these mechanically:

- State uses `@Observable`, `@State`, `@Environment` and `@Bindable`. Never `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject` or `@EnvironmentObject`.
- Concurrency uses `async`/`await`. Never `DispatchQueue`, `Thread`, `OperationQueue`, semaphores, completion handlers, or `[weak self]`.
- SwiftUI only: no `import UIKit`, no `UIScreen.main`.
- No `as!` force casts.
- Colors come only from `Color.gt*` and type only from `Font.gtHeading*` / `Font.gtBody*`. See [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md).

Beyond lint:

- Every interactive control gets an `accessibilityLabel` as it is built.
- Use real data. Don't hardcode sample data to make a screen look finished.
- Document functions with `///` comments.

## Naming conventions

### Files and types

| Kind | Rule | Examples |
|---|---|---|
| Views and components | Suffix `View` | `HomeView`, `EventDetailView`, `GTFilterChip` (shared components may use a `GT` prefix instead) |
| ViewModels | Suffix `VM` | `MapVM`, `RoutingVM`, `SearchVM` |
| Models | Nouns only | `Event`, `BusRoute`, `CampusLocation` |
| Services | Suffix `Service` | `AuthService`, `CampusSearchService` |
| Managers (stateful, long-lived) | Suffix `Manager` | `LocationManager`, `RouteManager` |
| Pure helpers | Plain noun, caseless `enum` | `DiningHours`, `BusArrivals`, `DistanceFormat` |

Pure helpers return values rather than perform actions, so their functions read as noun phrases (`steps(from:)`, `distance(from:to:)`) instead of verb-first.

### Functions

camelCase, verb first, reads like English.

- Good: `fetchEvents()`, `loadUserProfile()`, `signOut()`
- Bad: `eventsFetch()`, `userProfile()`, `doAuthThing()`

### Variables

camelCase and descriptive, with no unnecessary abbreviations. Booleans start with `is`, `has`, `should` or `can`: `isLoading`, `hasError`, `shouldRefresh`.

## Networking

- All backend calls go through `GTDataService`, with one extension file per data domain (`GTDataService+Events.swift`). Don't create a new service class per domain.
- Use `async`/`await`.
- Base URLs and keys live in `Config/Secrets.plist`, never in code.

## Testing

The Xcode project declares a `GeorgiaTechAppTests` target, but there are no tests in the repo yet. There is also no CI of any kind, so nothing builds or tests a pull request for you. Until that changes, verify your work by running the app on a simulator or device and by running `swiftlint`. If you add tests, use XCTest and mirror the app's feature folders.
