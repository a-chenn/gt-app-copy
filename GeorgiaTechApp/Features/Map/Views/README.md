# Map Views

SwiftUI views for the Map tab: the map and its layers, the search sheet's content, place detail, and routing.

## What's here

- `MapView.swift`: the screen. It owns the always-presented sheet and hides the tab bar, and a floating Home button leads back.
- Layers on the map: `MapPlacesLayer`, `MapBusRouteLayer`, `MapRouteOverlay`, `PlacePin`, `MapChipRailView`, `MapTopOverlaysView`.
- Place detail: `PlaceDetailView`, `PlaceDetailHero`, `PlaceMenuSection`, `LiveBusPopover`.
- Routing: `RouteOptionsView`, `RouteEndpointSearchView`, `ActiveNavigationView`.

## Rules

- Views render state and forward user actions to a ViewModel or manager (`MapVM`, `RoutingVM`, `RouteManager`). They don't do networking or persistence.
- UI-only state (a sheet detent, an expansion toggle) can live in the view. State that affects data belongs in a ViewModel.
- One pin and one detail card for every place, branching on `category`. See [docs/ARCHITECTURE.md](../../../../docs/ARCHITECTURE.md).
- Routing happens inside the main sheet, never in a second sheet.
