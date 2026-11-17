# Georgia Tech Campus App

The official Georgia Tech campus app for iOS, built by students in GT iOS Club in partnership with the Student Government Association (SGA). One app for dining, buses, campus locations, events and news.

## Status

Development started in January 2026. A first version is built and the team is in its second semester, fixing rough edges and preparing for a redesign. The plan:

| When | Milestone |
|---|---|
| Fall 2026 | Fix bugs, apply the new designs, reach a minimal viable product by the end of the semester |
| Spring 2027 | Full-semester beta with sampled groups of students |
| Summer 2027 | Soft launch |
| Fall 2027 | Campus-wide rollout (iOS first, Android later) |

## What it does

- **Home:** a masthead with live glance info, plus bands for the next bus, what's open and busy right now, tonight's events, GT dates, campus links and help numbers.
- **Map:** campus search, buildings, dining, printers, microwaves and vending machines, and routing by walking, biking, driving or bus with live TransLoc data.
- **Dining:** menus, nutrition, hours and accepted payments.
- **Events and news:** official GT events and news.
- **Account:** GT single sign-on, or continue as a guest.

Library room booking is a visible "coming soon" placeholder, because no backend exists for it yet.

## Documentation

| Doc | What it covers |
|---|---|
| [INSTALL.md](INSTALL.md) | Set up and run the app locally |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Branching, pull requests, naming conventions, testing |
| [docs/PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md) | What the app does, for whom, and feature priorities |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Folder structure, data flow, services, state management |
| [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) | Colors, typography, components, accessibility |
| [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) | Where the project is and what's next |
| [CLAUDE.md](CLAUDE.md) | Rules and context for AI coding agents working in this repo |

The app's data comes from a separate backend, the GT App API (repo: `Georgia-Tech-App-API`, next to this one in the SGA organization), and from TransLoc for live buses.
