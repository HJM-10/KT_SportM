# Mobile equipment rentals — design review

29 October 2026. Customer redesign introduced in 1.0.4+5; admin inventory and rental management added in 1.0.5+6.

## Admin equipment management — 1.0.5+6

The former read-only catalogue/desk has been replaced with three separate admin workspaces: Inventory, Rentals and History. Inventory is a searchable list with stock, daily rate, active state and an edit pencil on every row. Active/inactive filters and an Add equipment action are available above the list. Stock labels refer to total inventory, not date-specific availability.

Add/edit opens a dedicated scrolling form for name, sport, compatible venue or shared inventory, daily unit price, total stock, rental availability, description, brand, model/size, material, ball type, condition and image URL. Saves use the existing admin-only POST/PUT endpoints. All stored fields are validated even when scrolled out of view. Errors retain the edits and show the server restriction beside the persistent save button. Switching sport clears the venue selection so a mismatched venue is not silently submitted. Turning rental availability off stops new rentals while retaining history.

Rentals and History have separate lists, status filters and searches for equipment, customer, venue or rental ID. Tapping a rental opens customer, inventory, dates, quantity, price and payment details. Staff can cancel applicable rentals with confirmation, or record a return from collection day onward with damaged quantity and inspection notes. Existing server stock/refund rules remain authoritative. No payment, refund, inventory update or return was performed against live user data during automated validation.

`admin-implementation/` contains actual Flutter captures of the inventory list, editor and active rentals in both themes, using labelled sample fixture data. Reproduce with `flutter test --no-pub --dart-define=RENDER_ADMIN_RENTALS=true`. Full mobile suite: 62 tests passed. Analysis of lib and test: no issues. Tests cover admin routing, real save payloads, create/edit, compatible venue selection, search/filter behavior, server-rejected edits retaining values, validation of offscreen fields, damage inspection, cancellation, future-return restrictions, and 320px layouts at 150% text size, alongside the customer regressions.

## Implementation

The customer Equipment entry now opens Browse gear / My rentals, with a dedicated rental-details route. It uses the existing Clubhouse theme in light and dark modes. The staff rental desk remains available to administrators.

Browse cards display date-specific stock and daily unit pricing, with working venue and sport filters. Details show supplied specifications, editable dates, quantity controls and inclusive daily price arithmetic. The reserve action creates the existing server reservation and opens checkout; checkout launch failures retain the hold for payment from My rentals. Free rentals skip checkout. Active/history cards use readable states, server expiry timestamps in Pakistan time, and date-appropriate cancellation actions. Staff continues to record returns.

Catalogue and history requests have separate loading/retry states. Superseded availability responses are ignored. Details refresh stock before enabling reservation, and server conflicts refresh availability. The date picker and submission guard enforce the existing 90-day maximum.

The existing six illustrative gear images from frontend_web/public/gear were copied into frontend_mobile/assets/gear with their original prompts and provenance. These are labelled illustrative. Unmatched equipment uses a labelled sport-icon fallback; supplied non-illustrative HTTP(S) photos take precedence. No new image generation was required for the implementation.

### Actual app previews and validation

`implementation/` contains actual Flutter widget captures of browse, details and rental history in both themes, using test fixture data. They are separate from the earlier AI-generated concept boards.

Reproduce them from frontend_mobile with `flutter test --no-pub --dart-define=RENDER_RENTALS=true`. All 52 mobile tests passed, including rental quantity validation, inclusive request dates, duplicate-tap protection, stock-conflict recovery, sport/venue filtering, independent history retry and 320px-wide layouts at 150% text size. `flutter analyze --no-pub lib test` reported no issues. Tests do not collect a live payment or modify the database.

## Renders

- [Light flow](01-rental-flow-light.png)
- [Dark flow](02-rental-flow-dark.png)

Both boards show Browse gear, Rental details, and My rentals. They are AI-generated design concepts created with the built-in image-generation tool, not running-app screenshots. Prices, stock, venue names, condition, and product photographs are illustrative sample content.

## What the existing code shows

Reviewed frontend_mobile/lib/screens/equipment_screen.dart, frontend_mobile/lib/providers/theme_provider.dart, frontend_mobile/lib/services/payment_service.dart, backend/src/controllers/equipment.controller.js and backend/src/lib/equipment-policy.js.

- Catalogue and rental history occupy one long scrolling screen. History becomes harder to reach as inventory grows.
- Every product lists five specification rows, including repeated “Not specified by venue” values. This overwhelms name, venue, availability and price.
- Equipment imageUrl exists in the API but is unused by this screen.
- Dates appear in technical YYYY-MM-DD format. Quantity, price and payment terms are squeezed into an alert dialog.
- Rental and payment statuses are rendered as raw values rather than readable labels and deliberate next steps.
- The picker permits dates up to a year ahead without enforcing the server's 90-day maximum rental length.
- Both catalogue and history share one combined load/error boundary; a history request failure can prevent catalogue refresh.

## Proposed flow

1. Browse gear: separate local Browse gear / My rentals tabs, readable date range and inclusive day count, venue and sport filters, compact image cards with price and date-specific availability. Preserve any venue scope from the entry screen. Existing global Discover / Bookings / Profile navigation remains.
2. Rental details: show venue, supplied image or clearly labelled fallback, condition, expandable specifications, dates, quantity stepper bounded by available stock, explicit daily arithmetic and a persistent reserve action. Hide missing optional specs. Allow accessible typed quantity for larger counts.
3. My rentals: Active / History grouping, readable status badges, venue and dates, and the applicable next action. Continue payment for a valid pending hold, cancellation when permitted, and details/history after return or cancellation.

## Rules to preserve during implementation

- Total = daily unit rate × quantity × inclusive calendar days. Same-day rental costs one day. Use Pakistan calendar dates and enforce the 90-day maximum before submission.
- Availability and final total remain server-authoritative. Refresh after date changes, disable reservation while refreshing, reject stale responses, and recheck conflicts from the reserve endpoint. Do not show cached availability as current.
- Reserving creates an unpaid hold for paid items, then opens the current external checkout. Payment confirms the rental; reopening the app must refresh status. If checkout cannot open, retain the hold and show Continue payment. Zero-cost rentals are confirmed immediately by the server.
- Use an actual expiresAt for any expiry time/countdown; never restart a 30-minute timer on screen entry. Expired holds become cancelled through the existing lifecycle.
- Customer cancellation before collection day follows existing rules; same-day confirmed changes require staff. Paid cancellations enter the refund queue, so do not label them instantly refunded.
- Staff records returns and damage inspections. Customers do not get a self-return action. Keep the mobile admin rental desk separate from this customer redesign.
- Use supplied equipment images where available; generated fallbacks must remain labelled illustrative. No invented ratings, delivery, deposits or collection times.
- Implement independent loading/retry states, empty results with clear filters, unavailable stock, expired holds and failed payment presentation. Verify light/dark themes, large text and narrow layouts.

## Render review notes

The boards demonstrate hierarchy and visual direction. The generator highlighted Padel while also showing a cricket card and Court A while showing shared inventory. In implementation these sample mixed catalogues require All sports / All venues, or the cards must obey the selected filters. The confirmed shared-inventory sample says return to venue staff; actual details must use the assigned collection location or direct the customer to staff when none is supplied. Product thumbnails and exact spacing also vary between the generated theme boards; use a single shared component layout in Flutter. The rounded phone shells are presentation framing, not a proposal to change Android navigation or platform controls.

## Generation prompts

### Light

Use case: ui-mockup. Create a very high fidelity mobile app rental redesign presentation board for the existing Pakistan sports app "KT Smart Sport Hub". Landscape board, three complete tall phone screens side by side, straight-on flat UI, large and readable, restrained device outlines, no perspective, no cropped screens. Small board title "Equipment rentals / Light" and footer "Design concept • Sample data and illustrative equipment". Existing brand: forest green #174C36, warm cream #F5F3E9, off-white cards #FFFDF7, ink #142C21, subtle muted brass #B28C45. Roboto-like sans-serif, bold clean headings, generous spacing, 18px corner radii, fine borders, polished Flutter Material 3 aesthetic matching a premium community sports clubhouse. All screens feature realistic black and forest-green unbranded padel racket product imagery on warm neutral photo surfaces. No invented brands, ratings, deposits, delivery or cart. Local equipment subnavigation uses Browse gear / My rentals; global nav only Discover / Bookings / Profile.
SCREEN 1 Browse: back arrow and title "Equipment"; heading "Gear up. Play more."; subtitle "Rent from your venue."; Browse gear tab selected and My rentals unselected. Tappable date card with calendar icon "30–31 Oct 2026", smaller "2 days · Both dates included", edit affordance. Venue filter "Court A" and sport filter chips All, Padel, Cricket. Compact photo-led product card: racket image top right, "Padel racket", "Court A · Padel", green dot "4 available for these dates", bold "PKR 500" with "/ unit / day", outlined or filled small "View gear →". Second card for "Cricket bat", "Shared inventory", "PKR 300 / unit / day", availability "2 available for these dates". Include modest source label "Illustrative image" on product photos. Keep metadata out of catalogue.
SCREEN 2 Rental detail/review full screen: back arrow "Rental details"; mid-size product photo with "Illustrative image"; title "Padel racket", "Court A · Padel", badge "Good condition", inline collapsed "Equipment specifications" with chevron. Date selection card "30–31 Oct 2026", "2 days · Both dates included". Quantity row "Quantity" stepper minus, 2, plus, "4 available". Explicit price breakdown "PKR 500 × 2 units × 2 days", total "PKR 2,000". Small clear notice "Payment confirms your rental. Unpaid holds expire after 30 minutes." Sticky bottom full width primary action "Reserve & continue to payment". This action creates a hold then opens existing checkout; no falsely confirmed state.
SCREEN 3 My rentals: back arrow "Equipment"; heading "Your gear, sorted."; Browse gear and selected My rentals tabs. Active / History segmented pills. Card 1 status pill "Awaiting payment", "Padel racket · 2 units", "Court A", dates "30–31 Oct 2026", "PKR 2,000", amber modest notice "Pay before your hold expires", primary "Continue payment", subtle secondary "Cancel rental". Card 2 status "Confirmed", "Cricket bat · 1 unit", "Shared inventory", dates "1 Nov 2026", "PKR 300", short "Return to venue staff after use", secondary "View details". Do not show user self-return button; staff records returns. Global nav bottom. Use clear hierarchy, native-feeling touch targets, restrained premium photographic design, practical implementable UI. Ensure arithmetic consistent. No excessive marketing, gradients, floating decorations, or tiny illegible text.

### Dark

Use case: ui-mockup. Create a very high fidelity mobile app rental redesign presentation board for the existing Pakistan sports app "KT Smart Sport Hub". Landscape board, three complete tall phone screens side by side, straight-on flat UI, large and readable, restrained device outlines, no perspective, no cropped screens. Small board title "Equipment rentals / Dark" and footer "Design concept • Sample data and illustrative equipment". Dark theme of existing brand: background #081C14 deep pine, cards #10271E, cream text #EDF2E9, muted sage secondary text #B5C7BA, pale sage primary buttons #A3D9B9 with dark green text #092B1E, subtle brass #D9BB78. Product photography remains warm neutral, contrasted elegantly against dark pine UI. Never use black-on-dark text. Roboto-like sans-serif, bold clean headings, generous spacing, 18px corner radii, fine borders, polished Flutter Material 3 aesthetic matching a premium community sports clubhouse. Show a sophisticated dark theme consistently across all three screens, including inputs, date cards and navigation. All screens feature realistic black and forest-green unbranded padel racket product imagery on warm neutral photo surfaces. No invented brands, ratings, deposits, delivery or cart. Local equipment subnavigation uses Browse gear / My rentals; global nav only Discover / Bookings / Profile.
SCREEN 1 Browse: back arrow and title "Equipment"; heading "Gear up. Play more."; subtitle "Rent from your venue."; Browse gear tab selected and My rentals unselected. Tappable date card with calendar icon "30–31 Oct 2026", smaller "2 days · Both dates included", edit affordance. Venue filter "Court A" and sport filter chips All, Padel, Cricket. Compact photo-led product card: racket image top right, "Padel racket", "Court A · Padel", green dot "4 available for these dates", bold "PKR 500" with "/ unit / day", outlined or filled small "View gear →". Second card for "Cricket bat", "Shared inventory", "PKR 300 / unit / day", availability "2 available for these dates". Include modest source label "Illustrative image" on product photos. Keep metadata out of catalogue.
SCREEN 2 Rental detail/review full screen: back arrow "Rental details"; mid-size product photo with "Illustrative image"; title "Padel racket", "Court A · Padel", badge "Good condition", inline collapsed "Equipment specifications" with chevron. Date selection card "30–31 Oct 2026", "2 days · Both dates included". Quantity row "Quantity" stepper minus, 2, plus, "4 available". Explicit price breakdown "PKR 500 × 2 units × 2 days", total "PKR 2,000". Small clear notice "Payment confirms your rental. Unpaid holds expire after 30 minutes." Sticky bottom full width primary action "Reserve & continue to payment". This action creates a hold then opens existing checkout; no falsely confirmed state.
SCREEN 3 My rentals: back arrow "Equipment"; heading "Your gear, sorted."; Browse gear and selected My rentals tabs. Active / History segmented pills. Card 1 status pill "Awaiting payment", "Padel racket · 2 units", "Court A", dates "30–31 Oct 2026", "PKR 2,000", amber modest notice "Pay before your hold expires", primary "Continue payment", subtle secondary "Cancel rental". Card 2 status "Confirmed", "Cricket bat · 1 unit", "Shared inventory", dates "1 Nov 2026", "PKR 300", short "Return to venue staff after use", secondary "View details". Do not show user self-return button; staff records returns. Global nav bottom. Use clear hierarchy, native-feeling touch targets, restrained premium photographic design, practical implementable UI. Ensure arithmetic consistent. No excessive marketing, gradients, floating decorations, or tiny illegible text.

