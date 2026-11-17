# Services

Services talk to things outside the UI: the network, SwiftData, the system. They contain no SwiftUI and no presentation logic.

## What's here

- `GTData/GTDataService.swift`: generic networking and the launch sync. Each data domain is an extension file next to it (`GTDataService+Dining.swift`, `+Events.swift`, and so on). Add a new domain as a new extension, not a new service class.
- `AuthService.swift`: the GT SSO flow and Firebase sign-in and sign-out.
- `ConfigService.swift`: auth-gated remote config. Unused for now.

Feature-specific services live with their feature, for example `Features/Search/Services/`.

## Rules

- Services perform side effects: network requests, database writes, file and device access.
- ViewModels and Views call services. A View never talks to the network or SwiftData directly for writes.
- Use `async`/`await`. No completion handlers.
- Keep API base URLs and keys in `Config/Secrets.plist`, never in code.

See [docs/ARCHITECTURE.md](../../../docs/ARCHITECTURE.md) for the data flow.
