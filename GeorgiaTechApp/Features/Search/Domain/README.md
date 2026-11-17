# Search Domain

Plain value types and rules for search, with no UI and no networking.

## What's here

- `SearchCategories.swift`: the categories a user can search by (dining, printers, and so on). Search code switches over this enum exhaustively.
- `MapPlaceScope.swift`: the Popular, Nearby and Favorites scopes. These are computed from user state and location, so they are a separate type from `SearchCategories`.

## Rules

- Keep these types free of SwiftUI and side effects, so they are easy to reason about and test.
- Searching itself lives in `Features/Search/Services/`, and the results all convert to `SearchCardModel`. See [docs/ARCHITECTURE.md](../../../../docs/ARCHITECTURE.md).
