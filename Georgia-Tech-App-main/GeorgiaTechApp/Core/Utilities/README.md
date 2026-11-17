# Utilities

Small, reusable helpers with no feature ownership and no state.

## What's here

- **Pure domain helpers**, written as caseless `enum`s: `DiningHours`, `DiningMenu`, `BusArrivals`, `TransitPlanner`, `RouteNavigation`, `EventReminders`, `DistanceFormat`, `ReportIssue`, `PopularPlaces`. They take values in and return values out. Their functions read as noun phrases (`steps(from:)`) rather than verb-first.
- `APIUtility.swift`: reads the API base URL from `Config/Secrets.plist`.
- `GTAppearance.swift`: sets fonts on UIKit-drawn chrome (navigation titles, tab labels, segmented controls).
- `Extensions/`: `Color` and `Font+GT` (the design tokens), plus extensions for `ModelContext`, `MKPolyline`, `String` and `URLResponse`, and the screen background modifier.

## Rules

- Keep helpers generic and testable. If it needs state, networking or persistence, it isn't a utility.
- Colors and fonts come only from `Color.swift` and `Font+GT.swift`. See [docs/DESIGN_SYSTEM.md](../../../docs/DESIGN_SYSTEM.md).
- Don't let this folder become a dumping ground. Feature-specific code belongs in its feature.
