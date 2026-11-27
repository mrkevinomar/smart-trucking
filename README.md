# Smart Trucking

Return-trip cargo platform (Plataforma para viajes de retorno). Flutter Web / PWA.

This repository holds the **clickable prototype of the MVP core flow** (AE-89): the driver and
shipper journeys from the AE-79 study, section 4 (UX spec) and Appendix A defaults, with mocked
data and no backend. Spanish is the default language; English is available from S23.

Live prototype: https://mrkevinomar.github.io/smart-trucking/

## Requirements

- Flutter 3.44 or newer (stable channel) with web support enabled (`flutter config --enable-web`).
- Chrome for local development.

No third-party packages are used; the only dependencies are the Flutter SDK, `flutter_localizations`
(ships with the SDK) and `flutter_lints` for analysis.

## Run locally

```bash
flutter pub get
flutter run -d chrome
```

The app starts on S01 (role selection). Mocked sign-in on S02 accepts the code **123456**.

## Checks

```bash
flutter analyze        # must report "No issues found!"
flutter test           # unit tests (state machine, commission, formatters, copy tables)
                       # and widget tests (driver journey, shipper journey, filters,
                       # cancel consequences, EN toggle, timeline demo)
```

## Build and deploy the web build

```bash
# Build. --base-href must match the path the site is served from.
flutter build web --release --base-href /smart-trucking/      # GitHub Pages (project site)
flutter build web --release                                    # any host serving from "/"
```

The output in `build/web/` is static and can be served by any static host (GitHub Pages, S3 +
CloudFront, Netlify, nginx). It includes:

- `manifest.json` (name, icons, `display: standalone`, theme colour);
- `sw.js`, an app-shell service worker registered after the first frame. It precaches the shell,
  serves same-origin static assets cache-first and never caches anything under `/api/` (study 5.6:
  the service worker cache must exclude authenticated API responses);
- the `beforeinstallprompt` bridge in `index.html` that the in-app install sheet uses on
  Chromium browsers; Safari shows the manual "Add to Home Screen" steps instead.

### GitHub Pages

The `gh-pages` branch contains the built site. To publish a new build:

```bash
flutter build web --release --base-href /smart-trucking/
cd build/web
touch .nojekyll
git init -b gh-pages
git add -A
git commit -m "deploy: web build"
git push -f git@github.com:mrkevinomar/smart-trucking.git gh-pages
```

Then make sure the repository's Pages source is the `gh-pages` branch, root folder.

## Project layout

```
lib/
  app.dart                   MaterialApp, routes (one per S-id), localization delegates
  theme.dart                 Material 3 theme: 48 dp targets, contrast, visible focus
  core/
    enums.dart               ListingStatus and BookingStatus (two separate enums), roles, locale
    booking_state_machine.dart  4.5 transitions for bookings and for listings, cancel/dispute windows
    money.dart               Commission (A7.4), RefundRule (A7.6), strikes (A10.4), date/money format (4.6)
    models.dart              Trip, Load, Offer, Booking, profiles, filter models
    mock_data.dart           Mocked drivers, trips (with and without reference price) and loads
    app_state.dart           In-memory state, mocked transitions, notifications
  l10n/strings.dart          ES and EN copy tables (keys identical), state labels and notifications
  pwa/                       Install prompt bridge (web) and stub (tests)
  screens/
    onboarding_screens.dart  S01 S02 S03 S04 S05
    driver_screens.dart      S06 S07 S08 S09 (+ filter sheet) S21
    shipper_screens.dart     S11 S12 (+ filter sheet) S13 S14 S15 S17
    shared_screens.dart      S10 S16 S18 S19 S20 S22 S23, timeline demo
  widgets/common.dart        Screen frame, timeline, install sheet, cards, filter sheet frame
test/
  booking_state_machine_test.dart
  money_and_strings_test.dart
  journeys_test.dart
web/
  index.html  manifest.json  sw.js  icons/
```

## Demo controls

Controls labelled **Demo:** simulate the other party or the system (the shipper paying, the
driver picking up, operations deciding a dispute, OTP lock-out states, verification states).
They are not product UI; they exist so one person can walk both journeys end to end.

## Out of scope

Real authentication, payments, maps routing, document OCR, back-office (S24–S25),
notification delivery and store builds.
