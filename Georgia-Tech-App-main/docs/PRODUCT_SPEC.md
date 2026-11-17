# Product Spec

What the app does, who it is for, and what is in and out of scope. For how it is built, see [ARCHITECTURE.md](ARCHITECTURE.md). For timing, see [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md).

## Purpose

One official Georgia Tech app that replaces a scatter of separate tools. Students currently deal with:

- **Transportation:** TransLoc issues and student bus apps that go stale
- **Events:** no official mobile app for Engage events
- **Dining:** an inaccurate dining website
- **Campus locations:** a printer map that shows only the building
- **Scheduling:** websites only
- **News:** email and web only

The goal is one cohesive app where dining, transportation, locations, events and news work together. It does not need to replace every GT app. Apps that must exist for other reasons (for example the financial and virtual BuzzCard app, or the Engage-based CORE app) stay, and ours reads their data where it can.

## Users

Georgia Tech students. The main use is a quick lookup ("where is this building", "what's for lunch", "when's the next bus", "is the gym busy"), not long browsing. The app should answer in a few taps and get out of the way.

Staff who run campus services are a second audience: they are the data owners and partners the app depends on.

## Platforms

iOS only, for now. Roughly 80% or more of undergraduates use Apple devices, so iOS covers most of the student body. Android is planned later, and the backend is built to serve both.

## Core workflows

1. **Find a place and get there.** Search or tap a pin (building, dining hall, printer, microwave, vending machine, bus stop), see its detail card, and get walking, biking, driving or bus directions from one routing action. Bus routing uses live TransLoc data to show real trip times.
2. **Check dining.** Browse dining halls and restaurants with hours, menus, nutrition and accepted payments.
3. **See what's open, busy and next.** Home shows the next bus, what's open and how busy campus buildings are right now.
4. **See what's happening.** Browse GT events and news, and set reminders for events.
5. **Sign in with GT SSO**, or continue as a guest.

## What ships today

| Area | Status |
|---|---|
| Home (masthead, game day, right now, open now, tonight, GT dates, campus links, get help) | Shipped. Band order is user-editable. |
| Map: unified search, pins and detail cards for buildings, dining, appliances, bus stops | Shipped |
| Routing: walk, bike, drive and bus, with in-app turn-by-turn | Shipped |
| Live buses: positions, capacity, arrival estimates, route layer | Shipped |
| Dining: menus, nutrition, hours, favorites | Shipped. Dietary filters appear only when a menu has tagged foods. |
| Building occupancy | Shipped |
| Events and news | Shipped, with per-event reminders |
| Data-backed local alerts (bus arrivals, building capacity quiet times) | Shipped |
| GT SSO and guest mode | Shipped. Production SSO registration is pending OIT confirmation. |
| Settings, support and "report an issue" | Shipped |
| Library room booking | Placeholder only, "coming soon" |

## Planned, depends on partners

These need data access or approval we don't have yet. None ships as a mock.

- **Library room booking:** ready to build once OIT approves access.
- **Student printing** inside the app.
- **BuzzCard, BuzzFunds and dining dollar balances.**
- **Engage events** beyond the public feed, if access can be arranged.
- **Dining extras:** food trucks and the Wednesday Tech Green Market (the vendor list is only known day-of), plus micro markets.
- **Better appliance data:** printer, microwave and vending locations are collected by hand today. A real source with status (working, out of service) would replace that.
- **Building hours and floor plans:** the backend doesn't provide them yet.
- **"Upcoming" for the signed-in student** (their own RSVPs and bookings): needs personal data from a source that doesn't exist yet.

## Out of scope

- General user-authored alerts (exception: the data-backed bus and capacity alerts above)
- Class schedule tracking
- Weather
- Siri and Spotlight App Intents
- Anything shown with fake data. If a feature has no real source, it is absent or a labeled placeholder.

## Principles

- **Real data or nothing.** Every Home band shows real data or doesn't render.
- **One model for places.** Everything placeable on the map is the same kind of thing with a category. See ARCHITECTURE.
- **Native first.** Prefer system components and behavior over custom ones.
- **Accessible from the start.** Labels, Dynamic Type and dark mode are part of "done".
- **Handle student data carefully.** The team works with OIT on compliance, including FERPA.

## Open question

Is there a real, ongoing source for a separate "Tech News" feed beyond the news feed we already use? Don't design UI for one until that is answered.
