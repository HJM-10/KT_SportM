# Checklist implementation and demo verification

Updated 25 October 2026. This report covers the six rows in the user's screenshot. It supersedes the corresponding initial findings in PROJECT_HANDOVER.md. Work and tests use the isolated local demo database; production facilities and real payment credentials were not supplied or changed.

| Checklist area | Implemented behavior | Verification |
|---|---|---|
| Venue/court management | Editable session prices, capacity, daily opening/closing times, weekly closed days, dated closures and active/inactive facilities. Booking checks include the sport's active state. | Created **Checklist Demo Court** in Flutter: PKR 1,200, capacity 4, 08:00–22:00, Friday closed, maintenance on 26 October 10:00–11:00 PKT. API rejected times outside hours and during both closure types. |
| Live availability, bookings and history | Thirty-minute payment holds, automatic expiry worker, transactional court claims and overlap checks, retained cancelled booking history, live refresh after expiry. | Published 17:00–18:00 in Flutter, reserved a walk-in, verified customer history and rejected double booking. Deliberately expired a separate demo hold and verified the session reopened. Concurrent booking attempts are also tested against MariaDB. |
| Cancellation and rescheduling | Two-hour customer notice, admin override, same venue and duration on reschedule, retained original price, full-refund requests, explicit cash-return receipt, provider refund retry and late-payment reconciliation. | Customer booking #47 moved from 18:00 to 19:00 at PKR 1,200, then was cancelled. Staff completed its simulated refund with receipt **DEMO-REFUND-47-SIMULATED**; payment #89 and refund both show REFUNDED. Exact policy boundaries are tested. |
| Tournament creation and registration | Parent-row locking with current committed capacity checks, closed-registration rejection, distinct eligible teams, default PENDING manual fees, explicit cash-receipt acknowledgement and reasoned zero-value fee waivers. Unpaid team places expire. | Saved **Demo Manual Team** in Flutter with PENDING payment. Database checks exercise simultaneous registrations for one remaining place, cash acknowledgement, expiry, closed tournaments and waived-fee eligibility. |
| Fixtures, scheduling and results | Knockout byes and round progression, champion finalization, league table and completion, registered-venue and sport checks, date-range/closure/booking/event/match conflict checks and 30-minute rest. Completed results are locked. | Generated a three-team knockout in Flutter: one automatic bye, semifinal and final. Recorded results and verified **Knockout Team 1** as champion. The league finished with Team 1 on six points and the other two teams on one point each after a draw. Database checks reject schedule clashes and roll back partial generation. |
| Events and registration | Capacity locking, unpaid place expiry, customer and staff registration cancellation, whole-event cancellation with refund requests, and paid single-use attendance within the event window. | Customer coaching registration and cancellation were exercised in Flutter. Staff checked in **Demo Player** at **Checklist Demo Live Attendance**, cancelled the event while retaining attendance history, then completed payment #87's simulated PKR 100 refund with receipt **DEMO-EVENT-11-REFUND-SIMULATED**. Repeat and unauthorized check-in are also covered by database tests. |

## Flutter layout correction

The Generate Fixtures screen now has labels outside the fields, consistent vertical gaps, a registered-venue picker, a clear date/time button, a constrained wide-screen form and separate saved-fixture cards. Dates are shown in Pakistan time. Layout checks cover widths of 320 and 768 pixels, light and dark themes, and 160% text size.

## Checks

- Backend: **47 tests across 7 suites passed**.
- Flutter: **24 tests passed**, including four Fixtures layout cases; analyzer clean.
- MariaDB/API acceptance: **9 groups passed**, covering actual persistence and concurrent requests. Provider responses in these checks are simulated; no money moves.
- React compatibility build passed. The redesigned interface demonstrated to the user is Flutter at **http://localhost:5173**, not the separate React interface.
- `git diff --check` passed.

Repeat from the respective application directories:

```powershell
# backend (normal regression tests)
npm test -- --runInBand
# backend (explicitly guarded to the isolated local demo database)
node scripts/checklist-acceptance.js
# frontend_mobile
flutter analyze --no-pub
flutter test --no-pub
```

The acceptance script creates temporary users and facilities, then deletes only its own test records. `prepare-checklist-demo.js` retains clearly named walkthrough data; `check-demo-boundaries.js` deliberately creates an expired demo hold. Neither is a production migration or production seed.

## Payment limits of this demonstration

Cash receipts and cash refunds shown in the preview are simulated demo records. Stripe checkout reuse, duplicate/late settlement, refund idempotency and provider-failure retry were tested with simulated provider responses. A live Stripe charge or refund has **not** been verified; that requires configured provider credentials and webhook delivery. REFUNDED is recorded only after explicit staff acknowledgement of cash returned or provider confirmation of an online refund.

Evidence is saved in `qa/evidence/checklist-*.png`; backend execution details are in `qa/checklist-unit-tests.log` and `qa/checklist-acceptance.log`.

The final persisted state was independently checked and saved in `qa/evidence/checklist-final-state.json`. It confirms both tournament champions, released cancelled/expired booking slots, completed booking and event refunds, retained attendance, and automatic expiry of the unpaid manual team entry.
