# Models

Models describe the app's data. They hold no networking, persistence logic or SwiftUI layout.

## What's here

- `JSON/`: `Decodable` types that match the backend's responses exactly (`EventJSON`, `RestaurantJSON`, ...).
- `SwiftData/`: `@Model` entities stored on the device (`Event`, `Restaurant`, `CampusLocation`, ...). The backend's data lives here between syncs.
- `UI Models/`: small view-ready types for live data that is never stored (`BusLive`, `BusStopEstimate`).

Feature-scoped models live with their feature, for example `Features/Search/Models/RecentSearch.swift`.

## Rules

- A backend response is decoded into a `JSON` type, then converted into a SwiftData `@Model`.
- Name models as nouns with no suffix, except the `JSON` DTOs.
- Don't add a separate `Building` model. Buildings are a `category` of `CampusLocation`. See [docs/ARCHITECTURE.md](../../../docs/ARCHITECTURE.md).
