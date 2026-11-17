# Development Plan

Where the project is and what comes next. Last updated October 2026. For what the app does, see [PRODUCT_SPEC.md](PRODUCT_SPEC.md).

## Where we are

Development started in January 2026 and is now in its second semester. A first version is built and runs on real devices. Everything in "What ships today" in the product spec works against real data. This semester is about fixing rough edges, applying new designs, and getting ready for a beta.

## Timeline

| When | Milestone |
|---|---|
| Fall 2026 | Fix bugs, apply new designs, reach a minimal viable product by the end of the semester |
| Spring 2027 | Full-semester beta with sampled groups of students |
| Summer 2027 | Soft launch |
| Fall 2027 | Campus-wide rollout on iOS. Android follows later. |
| About a year out | iOS Club moves to a maintenance role: one or two developers plus a full-time OIT liaison |

## This semester

### 1. Apply the new designs

New designs are arriving. The color palette and type scale from the design spec are already in the app (see [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)). Screen layouts will be rebuilt as the designs land. While that happens:

- Keep building on the shared components and the unified location model, so a redesign is a change in a few places.
- Don't polish a screen's layout that is about to be redesigned. Fix its bugs and leave the look.
- When a design conflicts with this repo's docs, the design wins. Update the doc in the same pull request.

### 2. Fix known issues

From the October 2026 data audit:

- **Bus arrival estimate near zero while a bus waits at a stop.** Top priority.
- **Sign-out doesn't clear on-device user data** (saved places, recents, favorites), so a shared device shows the previous person's history.
- **Appliance locations refresh all-or-nothing.** If one of the three calls fails, none update.
- **Building occupancy is labeled "live"** but is only as fresh as the last sync, and shows no last-updated time.
- **Dining hours are entered by hand,** so holiday hours can be wrong. Automatic hours are in progress.
- **Fixed limits** of 500 events and 200 news articles, with no paging.
- **Home's GT Dates band stays hidden** until the backend has dates entered.

### 3. Partner and compliance work

These gate features and the release, and mostly don't need code:

- **OIT:** confirm compliance (including FERPA and student-data handling), finalize production SSO registration, and approve library room booking.
- **Institute Communications:** branding, copyright and trademark sign-off so the app can ship in the App Store as a Georgia Tech app.
- **Data stewards:** a named owner and a reliable source for each feature, especially occupancy, academic dates, and printers, microwaves and vending machines.
- **TransLoc:** GT's bus data vendor is expected to change in fiscal 2027. Stay in contact with Parking and Transportation so the bus integration can adapt.

### 4. Beta readiness

- Apple Developer Program account, funded through SGA, for TestFlight and the App Store.
- Decide whether to add tests, and a CI check for build and lint. Today there is neither.
- Plan SwiftData migration handling before the beta puts local data on real devices.
- Keep these docs and the data feature map current, since they are the handoff to the team that maintains the app.

## Next, once partners allow

- Library room booking (OIT approval)
- Student printing
- BuzzCard, BuzzFunds and dining dollar balances
- Food trucks and the Wednesday Tech Green Market
- Engage events beyond the public feed
- Android

## Sequencing rules

- The unified location model comes before any new place type. A new type is a new `category`, not a new view or service.
- The metadata-driven sync comes before any new data domain goes live, so each one gets smart refresh for free.
- A feature without a real data source doesn't ship as a mock.
