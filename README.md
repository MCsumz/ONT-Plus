<p align="center">
  <img alt="ONT Plus" src="assets/icon/ont_logo_square_color_white_1024x1024.png" width="120" />
</p>

<h1 align="center">ONT Plus</h1>

<p align="center">
  <b>OpenNutriTracker, with a faster diary.</b><br />
  A fork of <a href="https://github.com/simonoppowa/OpenNutriTracker">OpenNutriTracker</a> 2.7.0 — free, open source, private —
  with quality-of-life changes to logging and reviewing your days.
</p>

<p align="center">
  <a href="https://github.com/MCsumz/ONT-Plus/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/MCsumz/ONT-Plus?style=flat-square&color=22de5f" /></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-GPLv3-22de5f?style=flat-square" /></a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-Android-lightgrey?style=flat-square" />
  <a href="https://github.com/simonoppowa/OpenNutriTracker"><img alt="Upstream" src="https://img.shields.io/badge/upstream-OpenNutriTracker%202.7.0-blue?style=flat-square" /></a>
</p>

## What's different

Everything from OpenNutriTracker 2.7.0, plus:

- **Swipe to delete** — swipe a logged food left and confirm. Replaces dragging it onto the trash bar.
- **Move between meals** — long-press a food and drag it onto Breakfast, Lunch, Dinner or Snack.
  The target section lights up, and the page scrolls while you hold the food near the top or bottom.
  Or use **Move to…** in the food's ⋮ menu. Only the meal changes; the day's totals stay as they are.
- **Net kcal at a glance** — each Diary day shows how much is left (**+**) or over (**−**) the goal,
  with *eaten · burned · goal* underneath. The calendar shows that number under every logged day.
- **Full-screen edit** — tap a logged food to open the same detail screen as when you added it,
  pre-filled with what you logged: live calories, macros and nutrients, unit, a meal picker and
  **Save changes**. The day's totals adjust by the difference.
- In the Diary, **Copy to today** for past days now lives in each food's ⋮ menu, so long-press is free for dragging.

## Install (Android)

1. Download `ONT-Plus-<version>.apk` from the [latest release](https://github.com/MCsumz/ONT-Plus/releases/latest).
2. Open it on your phone and allow installing from your browser or file manager when Android asks.

ONT Plus installs **next to** the official OpenNutriTracker as its own app, so both can stay on
the phone while you move over.

iOS builds are not provided yet and have not been tested.

### Moving your data from OpenNutriTracker

ONT Plus is signed with its own key, so it can't update the official app in place, and the two
apps don't share data. To bring your history over:

1. In **OpenNutriTracker**: Settings → Export → **JSON**.
2. In **ONT Plus**: complete the first-time setup, then Settings → Import and pick that file.
3. Check your diary, then uninstall OpenNutriTracker if you like.

The JSON export carries your diary, activities, goal history, weight log, recipes, favourites,
photos and goal settings. The body profile from the first-time setup (height, age, sex, activity
level) is not part of it, so you enter that once. The CSV export only covers diary entries,
activities and daily totals — use JSON for a full move.

## Known limitations

- The app's own food database server (USDA / BLS and more via Supabase) is not configured in these
  builds; food search uses Open Food Facts, plus your own foods and recipes.
- Crash reporting (Sentry) is not configured.
- Translations of the new texts fall back to English.

## Building

Same toolchain as upstream (Flutter 3.44.6 via [FVM](https://fvm.app/), JDK 17, Android SDK 36):

```sh
cp .env.example .env              # placeholders are fine for a local build
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter build apk --flavor develop --debug
```

Releases use the `develop` flavor (label **ONT Plus**, package `….opennutritracker.develop`)
signed with the fork's release key via `android/key.properties`, which is not in the repository.

## Credits and license

ONT Plus is built on [OpenNutriTracker](https://github.com/simonoppowa/OpenNutriTracker) by
[@simonoppowa](https://github.com/simonoppowa) and its contributors; nearly all of the app is their work. Upstream's original README
is kept in [docs/upstream-README.md](docs/upstream-README.md).

Like the original, ONT Plus is licensed under the [GNU GPLv3](LICENSE). It is not affiliated with
or endorsed by the OpenNutriTracker project — please report issues with the changes above here,
not upstream.

Nutrition information is for general guidance only and is not medical advice.
