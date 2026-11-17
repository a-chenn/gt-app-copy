# Design System

The visual rules for the app: principles, color, type, shared components and accessibility. Last updated October 2026.

**New screen designs are in progress.** The color palette and type scale below come from the design spec and are already in the app. Screen layouts are not documented here, because they are being redesigned. For how a screen looks today, read its view code. When a new design changes a rule on this page, update the page in the same pull request.

## Principles

- **Feel native.** The quality bar is Apple Maps and Apple Calendar: a native iOS app with a confident Georgia Tech identity, not a university website.
- **Use the system.** Prefer native components (`List`, `NavigationStack`, `.sheet`, `.presentationDetents`) and system materials over hand-built equivalents. A custom component needs a specific reason the system one can't do the job. The map's draggable sheet is the example.
- **Reuse components.** Build with the shared components below instead of re-creating their look per screen.
- **Real content only.** No placeholder or stock photos. Places without a photo use an icon in a tinted circle.

## Color

Defined in `Core/Utilities/Extensions/Color.swift`. Every name carries the `gt` prefix so none can collide with an Apple system color. The values come from the design spec's "01. Color" board. **This is the only palette.** Don't use a raw hex, a system color like `Color.red`, or a new color without adding it to `Color.swift` and the spec.

| Group | Tokens |
|---|---|
| Core (official GA Tech) | `gtGold` `#B39051` · `gtWhite` `#FFFFFF` · `gtDarkGold` `#8F713D` · `gtNavy` `#051E39` |
| Secondary (official) | `gtDiploma` `#F9F6E5` · `gtBuzz` `#EAAA00` |
| Accent (official) | `gtCampanile` `#048A81` · `gtBurdell` `#BBE6F2` · `gtTechLawn` `#066034` · `gtWhistle` `#660064` · `gtAzalea` `#D90368` |
| Gradient stops (official) | `gtLightGold` `#DEBD88` · `gtMediumNavy` `#003D69` · `gtBrightBlue` `#004C97` |
| Text and background (pending approval) | `gtPrimaryText` `#242424` · `gtSecondaryText` `#515151` · `gtBackground` `#F4F4F4` |
| Status (pending approval) | `gtRed` `#DE1010` · `gtGreen` `#04924B` |
| Gray (pending approval) | `gtGray1` `#E9EAE9` · `gtGray2` `#AAAAAA` |
| Overlay and map (pending approval) | `gtOverlay1` black 10% · `gtOverlay2` black 5% · `gtMapWhite` white 80% · `gtMapGlass` white 60% |

Gradients: `LinearGradient.gtGoldGradient` (Dark Gold, Gold, Light Gold, Dark Gold) and `.gtNavyGradient` (Navy, Medium Navy, Bright Blue, Navy). Use them as a shorthand in any `ShapeStyle` position, for example `.fill(.gtGoldGradient)`.

### Dark mode

The spec gives one value per color and no dark variants. `gtPrimaryText`, `gtSecondaryText` and `gtBackground` hold the spec value in light mode and fall back to the matching iOS semantic color in dark mode, since a fixed `#242424` would be unreadable on black. Cards are `gtWhite` in light mode and `gtNavy` in dark mode (see `gtCard()`). Ask the designers for dark values when the new designs arrive.

Every other color is fixed. Before shipping a screen that leans on one, check contrast in both appearances: 4.5:1 for text, 3:1 for icons and state indicators. If one value can't satisfy both, branch on `colorScheme`, for example `gtGold` in dark and `gtDarkGold` in light.

### Contrast notes

| Color | Against white | Use |
|---|---|---|
| `gtGold` | 2.99:1 | Fills, rules, selection on dark surfaces. Just under the 3:1 minimum for graphics, so in light mode use `gtDarkGold` (4.6:1) wherever gold must carry meaning. |
| `gtBuzz` | 2.05:1 | Fill-only, behind dark text or on dark surfaces. Never paints text, a glyph, a bar or a ring on a light background. |
| `gtDarkGold` | 4.6:1 | Gold text and icons on light surfaces |

Anything drawn on a light-gold tint, such as map pins and row icons, takes a navy glyph (`LocationCategory.glyphColor`), because white on those tints measures only 2 to 3:1. A color that paints a foreground is held to a stricter bar than one that fills a shape behind dark text.

## Typography

Defined in `Core/Utilities/Extensions/Font+GT.swift`, from the design spec's "02. Typography" board. Roboto Slab is for headings 1 to 3 and Roboto for everything else. The app bundles three cuts: Roboto Slab SemiBold, Roboto SemiBold and Roboto Regular. Their licenses show in Settings, under About and Font Licenses.

| Style | Font | Size | Weight |
|---|---|---|---|
| `Font.gtHeading1` | Roboto Slab | 32 | Semibold |
| `Font.gtHeading2` | Roboto Slab | 24 | Semibold |
| `Font.gtHeading3` | Roboto Slab | 20 | Semibold |
| `Font.gtHeading4` | Roboto | 16 | Semibold |
| `Font.gtHeading5` | Roboto | 14 | Semibold |
| `Font.gtHeading6` | Roboto | 12 | Semibold |
| `Font.gtBody1` | Roboto | 16 | Regular |
| `Font.gtBody2` | Roboto | 14 | Regular |
| `Font.gtBody3` | Roboto | 12 | Regular |
| `Font.gtBody4` | Roboto | 10 | Regular |

Use these styles only. Never `.font(.headline)` or a bare `Font.custom(_:size:)`. Each style is declared `relativeTo:` a system text style so it still scales with Dynamic Type, and a bare custom font would not.

The spec also gives a line height per style (Heading 1 is 120%, Body 3 and 4 are 1.4, the rest 1.3). SwiftUI's `Font` can't carry one, so it isn't applied yet. SF Symbol sizes use `.font(.system(size:weight:))`. Navigation titles, tab labels and other UIKit-drawn chrome get the same fonts through `GTAppearance`.

## Homepage header (Developer Handoff)

The Home frame on the Figma Developer Handoff page uses a 402 pt reference width,
16 pt side insets, and a hex-pattern mask exported directly from the design. The
pattern fades from `gtGold` at 50% opacity to transparent across 187 pt; the status
bar has a separate `gtBackground`-to-transparent scrim. The header uses the
handoff logo export through `GTLockup(style: .homeHeader)`, a 44 pt settings target,
and `gtHeading1` for the personalized “Hey {first name},” greeting.

The featured carousel has four sample cards for this implementation ticket, as
explicitly requested. It is separate from the persisted event feed. Cards use
`gtMediumNavy`, a 16 pt radius, 12 pt horizontal / 16 pt vertical insets, and
`gtFeaturedEventText` (`#F1F1F1`). The label, title, and detail use `gtHeading6`,
`gtHeading2`, and `gtBody2`. Pagination dots are 8 pt with 8 pt gaps; inactive dots
use medium navy at 30% opacity. The prior live game-day band is replaced on Home
by this fixed-position carousel; its component remains available for real data.
Other Home bands retain their existing layout and ordering.

## Shared components

| Component | Use |
|---|---|
| `GTSectionHeader` | Heading for a band or section, with a short gold rule and an optional trailing control. |
| `GTMicroLabel` | Small uppercase caption above a number or a row. |
| `.gtCard(radius:padding:)` | Card chrome: fill, hairline navy border, soft navy shadow. |
| `GTFilterChip` | Every filter capsule: building filters, event categories, dietary filters. Don't build another. |
| `GTCapsuleButton` | Redesign button. A capsule with a title and/or icon; icon only makes a circle. Styles: `.standard` (white), `.selected` (navy), `.highlight` (gold). `.controlSize(.small)` gives the compact 36 pt size used on the map; `isFullWidth: true` stretches it (the sheet's "View All", "Directions"). |
| `GTCategoryChip` | Redesign category chip: icon and title, white at rest, navy when selected. Honors `.controlSize(.small)` like `GTCapsuleButton`. |
| `GTCapsuleScroll` | Redesign horizontal rail that holds chips and icon buttons. |
| `GTSearchBar` | Redesign search field: gray at rest, white with an X and a search button when focused. |
| `GTSearchResultRow` | Redesign search result: icon, title, path subtitle, chevron. |
| `PlaceHeartRow` / `PlaceHeartCard` | Map-sheet place lists (Recents, Suggested, Favorites): title, address line, save heart, in a white list card. |
| `SheetBackHeader` | "‹ Title" header for every in-sheet sub-page (Recents, Favorites, a bus stop, a bus, directions). |
| `GTLockup` | The Georgia Tech mark. `onDark: true` pins the reversed cut for navy surfaces. |
| `GTDetailHero` | Header for any opened thing (a place, an event, an article): photo under a scrim, or a navy gradient when there is no photo. |
| `GTBodyText` | All long-form copy. The feeds' HTML stripper loses paragraph breaks, and this restores them. Never a bare `Text` for an article. |
| `ExternalLinkButton` | Every link that leaves the app. See below. |
| `PlaceImageView` | Place photos. It pins its own width so an overflowing `scaledToFill` image can't drag its card out of the margins. |
| `gtScreenBackground()` | The background behind every scrolling screen. |

The five "Redesign" components live in `Core/Components/` next to `GTFilterChip` and the existing search views, which stay until their screens are rebuilt. Every file has a `#Preview` showing each state.

```swift
GTCapsuleScroll {
    GTCapsuleButton(icon: "heart.fill", label: "Favorites", iconColor: .gtAzalea) { }
    GTCapsuleButton(icon: "line.3.horizontal.decrease", label: "Filters") { }
    GTCategoryChip("Dining", icon: "fork.knife", isSelected: isDining) { isDining.toggle() }
}

GTSearchBar(text: $query, onSubmit: { runSearch() })

GTSearchResultRow(icon: "fork.knife", title: "Dining", subtitle: "Maps > Dining") { open() }
```

A gold `GTCapsuleButton` uses navy text, not the white in the design board, because white on `gtGold` is 2.99:1 and text needs 4.5:1.

### Rules that outlive any redesign

- **One pin, one detail card.** Everything placeable on the map renders through one pin component and one detail card, branching on `category`. See [ARCHITECTURE.md](ARCHITECTURE.md). A live bus is the exception: it is temporary telemetry and gets its own marker and a small popover.
- **Leaving the app is confirmed.** Every web or mail exit goes through `ExternalLinkButton`, which asks "Open {host}? This leaves the app." before opening. No bare `Link` and no direct `openURL` at feature level. The Apple Maps hand-off confirms with its own alert, and the jump to iOS Settings for location permission is exempt.
- **Dark mode is checked, not assumed.** A brand color that reads as structure on a light screen can vanish on a dark one, such as navy text on near-black. Screenshot both appearances before shipping.
- **Cards and lists use the system where they can.** Prefer `List` and `Section` over hand-built rows unless the layout truly can't be expressed with them.

## Iconography

SF Symbols only. Use rendering modes deliberately: monochrome for neutral chrome, hierarchical or a `Color.gt*` palette for category-tinted icons. Keep one weight and scale per context, for example every list-row leading icon the same, so the set reads as one system.

## Spacing

No custom spacing, shadow or corner-radius constants file. Use native SwiftUI spacing: system padding, `Spacer()`, and stack spacing. If one numeric value really needs sharing, prefer a single small constant next to the code that uses it.

## Logos

The Georgia Tech marks are vector assets in `Assets.xcassets`, each with a light (full color) and a dark (gold and white) variant. Always use `GTLockup` and never redraw the mark.

| Asset | Ratio | Use |
|---|---|---|
| `GTLogoOneLine` | 3.3:1 | Headers and toolbars, where the wordmark must stay legible small |
| `GTLogoHorizontal` | 2.8:1 | Wider spots where a two-line wordmark fits |
| `GTLogoVertical` | 1:1 | Splash and centered moments, such as Login |
| `GTLogoExtended` | 3.7:1 | The widest lockup |

Give every instance an `accessibilityLabel("Georgia Tech")`. The marks are registered trademarks: never recolor, stretch or rebuild them. If a lockup you need is missing, ask.

## Accessibility

Accessibility is part of done, not a later pass.

- Every icon-only control gets an `accessibilityLabel`, and an `accessibilityHint` where useful.
- Prefer native controls, which carry correct behavior. A custom control, like the map's draggable sheet, needs explicit traits and labels.
- Don't override Dynamic Type sizing without a specific reason.
- Check VoiceOver and at least one large Dynamic Type size on every new screen.

## Enforcement

`.swiftlint.yml` blocks the banned patterns: no `ObservableObject` family, no `DispatchQueue`, no `import UIKit`, no hardcoded system colors. Naming conventions are enforced in review. A few UIKit symbols are used without importing UIKit, where SwiftUI has no equivalent: `UIImage(named:)` in `PlaceImageView` to test whether an asset exists, `UIFont` in `GTAppearance` for navigation and tab chrome, and `UIColor` in `Color.swift` for the dark-mode fallbacks.
