# UI Models

View-ready types for data that is shaped for display and never stored.

## What's here

- `BusLive.swift`: a live bus's current position, heading and capacity from TransLoc.
- `BusStopEstimate.swift`: a live arrival estimate for one bus at one stop.

Both come from polling and live only in memory. Stored data belongs in `Core/Models/SwiftData/` instead.

## Rules

- Keep these types small and free of networking and persistence.
- The main presentation model for places, `SearchCardModel`, lives with search in `Features/Search/Models/`. See [docs/ARCHITECTURE.md](../../../../docs/ARCHITECTURE.md).
