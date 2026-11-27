<p align="center">
  <img alt="ONT+" src="assets/icon/ont_logo_square_color_white_1024x1024.png" width="120" />
</p>

<h1 align="center">ONT+</h1>

<p align="center">
  <b>OpenNutriTracker, with a faster diary.</b><br />
  A fork of <a href="https://github.com/simonoppowa/OpenNutriTracker">OpenNutriTracker</a> 2.7.0 — free, open source, private —
  with quality-of-life changes to logging and reviewing your days.
</p>

<p align="center">
  <a href="https://github.com/MCsumz/ONT-Plus/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/MCsumz/ONT-Plus?style=flat-square&color=22de5f" /></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-GPLv3-22de5f?style=flat-square" /></a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey?style=flat-square" />
  <a href="https://github.com/simonoppowa/OpenNutriTracker"><img alt="Upstream" src="https://img.shields.io/badge/upstream-OpenNutriTracker%202.7.0-blue?style=flat-square" /></a>
</p>

## What's different

Everything from OpenNutriTracker 2.7.0, plus:

- **Swipe through your days on Home** — Home opens on today; swipe left for the next day, right for
  the previous one, and the page slides along with your finger. A date bar has arrows, a calendar
  and a **Today** button. Past days show what you logged against that day's goal; days ahead are
  for planning, and whatever you add there is logged on that day. The Diary stays the overview
  and archive.
- **Sync with your other phone** — keep ONT+ on two phones (Android and iPhone alike) in step: one
  shows a QR code, the other scans it, and both end up with the same data. Entries added, edited
  or deleted on either phone since the last sync are carried over — a deletion is not brought back
  by the other phone. It runs over your Wi-Fi or hotspot only, encrypted with a one-time key in the
  code; no server, no account. A brand-new phone can take everything, profile included, straight
  from the welcome screen.
- **All-inclusive backup** — the JSON export now holds everything: diary, activities, goal history,
  the full weight log, water, fasting sessions, recipes, custom foods, favourites, photos, the body
  profile from the first-time setup and your preferences (theme, units, food databases, display
  options, day start). Importing merges by entry, so nothing is overwritten wholesale.
- **Photo quick add** — in **Quick add**, take a photo of your meal or pick one from the gallery;
  it becomes the entry's thumbnail, and with a photo the title is optional — photo, calories, done.
- **Pieces at a glance** — a food logged in servings shows the count on its row, e.g. *2 slices · 76 g*,
  not only the weight.
- **Your profile, your name** — the Profile tab and title show your profile's name and picture once
  you set them, instead of "You" and a generic icon.
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
- **Made for ONT+** — Report error opens an issue here on GitHub, Rate stars this repository, and
  Share sends the ONT+ releases link.
- **Smoother** — Home and the Diary update in place after you add, edit or delete something, without
  a loading flash or losing your scroll position; food photos are decoded at the size they are shown,
  so lists scroll more smoothly and use far less memory.

## Install

### Android

1. Download `ONT-Plus-<version>.apk` from the [latest release](https://github.com/MCsumz/ONT-Plus/releases/latest).
2. Open it on your phone and allow installing from your browser or file manager when Android asks.

ONT+ installs **next to** the official OpenNutriTracker as its own app, so both can stay on
the phone while you move over.

### iOS (15.5 or later)

The release also carries `ONT-Plus-<version>.ipa`. It is **unsigned**: install it with a sideloading
tool such as [AltStore](https://altstore.io), [Sideloadly](https://sideloadly.io) or TrollStore,
which signs it with your own Apple ID. With a free Apple ID that signature lasts 7 days and has to
be refreshed, and the home-screen widget may not work. The iOS build has not been tested on a
device yet.

### Moving your data from OpenNutriTracker

ONT+ is signed with its own key, so it can't update the official app in place, and the two
apps don't share data. To bring your history over:

1. In **OpenNutriTracker**: Settings → Export → **JSON**.
2. In **ONT+**: complete the first-time setup, then Settings → Import and pick that file.
3. Check your diary, then uninstall OpenNutriTracker if you like.

The original app's export leaves out the body profile from the first-time setup, so you enter
that once. Between two ONT+ installs nothing needs re-entering: use **Sync with another phone**
or ONT+'s own JSON export, which includes everything. CSV exports only cover diary entries,
activities and daily totals.

### Updating ONT+

Install a newer ONT+ APK over the one you have; your data stays. Make a JSON backup first if you
like (Settings → Export).

## Known limitations

- The app's own food database server (USDA / BLS and more via Supabase) is not configured in these
  builds; food search uses Open Food Facts, plus your own foods and recipes.
- Crash reporting (Sentry) is not configured.
- Translations of the new texts fall back to English.
- Phone-to-phone sync needs both phones on the same Wi-Fi or hotspot and the same ONT+ version.
  It carries the active profile; AI keys, reminders and health-app links stay per phone.

## Privacy

ONT+ keeps upstream's privacy design unchanged; the section below is upstream's, as it applies to this build. The one addition is the phone-to-phone sync, which talks only to your other phone, directly over your local network, encrypted with a one-time key shown in the QR code. Nothing goes through a server.


No account, no sign-in, no analytics, no ads. Your profile, diary, activities, weight, water and fasting history, custom meals, and recipes live in local [Hive](https://pub.dev/packages/hive_ce) boxes encrypted with AES-256. The key is generated on first launch, kept in the Android Keystore / iOS Keychain, and never transmitted ([source](lib/core/utils/secure_app_storage_provider.dart)). **Settings → Delete all my data** wipes the active profile. Formal policy: [Data Protection](https://www.iubenda.com/privacy-policy/53501884).

**What leaves your device.** These destinations, nothing else, and the last five only if you turn them on — plus one more, set out below, if you point the app at a server of your own:

| Destination | When | What is sent |
| :-- | :-- | :-- |
| [Open Food Facts](https://world.openfoodfacts.org/) | Food search, barcode scan, or whenever a food's photograph is shown — in search results, on a meal screen, and on the diary card of a meal you have already logged | The search term or barcode. A word search also sends your device's **language** code to rank results; the fallback search and the barcode lookup send no locale at all. Your **country is never sent** — the country boost is applied on your device, to the results that come back. A photograph's address contains that product's barcode. Searches and product lookups identify the app by name, platform and version; photograph downloads do not |
| Supabase reference backend | Food search | The text you typed; your **device's** language code, when it is one the backend has food names in; and which food databases you have left switched on — that list travels on every search, because onboarding starts one of the five off |
| App Store (iOS) / Google Play (Android) | Opening Settings → About → Support OpenNutriTracker, and leaving a tip there. On Android also at every start, to finish a tip an earlier run left open | A request for the three tips' store prices. A tip's payment goes to Apple or Google and never passes through the app, which sees only the tip's product ID, the purchase status and a purchase token it does not store |
| [Anthropic](https://www.anthropic.com/) | **Only if you save your own API key and pick Anthropic** | The meal line you type on the multi-item add screen, or a meal photo you choose to read there, and your app language |
| [OpenAI](https://openai.com/) | **Only if you save your own API key and pick OpenAI** | As the Anthropic row, plus the model you chose |
| [OpenRouter](https://openrouter.ai/) | **Only if you save your own API key and pick OpenRouter** | As the Anthropic row, plus the model you chose |
| └ the vendor serving it | | Named in Settings; pinned, so it is the vendor the model names |
| [Google Gemini API](https://ai.google.dev/gemini-api/terms) | **Only if you enter Google's Gemini address (`generativelanguage.googleapis.com`) as your own server** — from the moment you type it, as the own-server row below describes | As that row: the meal line or photo, your app language, and the model name you typed. Google receives it under its Gemini API terms: on unpaid use it may use it to improve its products and machine learning, and human reviewers may read it; on paid use, and on all use in the EEA, Switzerland and the UK, it does not, but logs it for a limited time to detect misuse |
| [Sentry](https://sentry.io) | **Only if you opt in** | Crash traces, app and OS version, device model |

**And one destination this project cannot name.** Every row above is a company with a published policy you can hold it to. If you point the app at a server you run, the destination is a machine of your choosing — so this row states a **rule** rather than a party. It is set apart deliberately: an open-ended entry in the list above would weaken the closed-list promise the list exists to make. It earns a place anyway, because burying the most privacy-relevant destination in prose would read as evasive.

| Destination | When | What is sent |
| :-- | :-- | :-- |
| **The address you entered, and nothing else** | **From the moment you type a server address in Settings, not from when you save it** — when you change the address and leave the field, when you press *Load models*, when you save (the setup check), and each time a meal line or photo is read | A models-list request when you change the address or press *Load models*; a fixed example line and a bundled photograph on save; otherwise the meal line or the photo, your app language, and the model name you typed |

This is the one row you can falsify yourself: your own server's access log settles it, where no user can ever settle a claim about a vendor's retention. **No third party receives anything on this path**, unless the address is Google's Gemini API, which is not a server you run: that is the Google row above, and the app names Google before you agree. Either way the data does not stay put. It leaves the device, to the address you named, and the app will not send it in the clear to anything that is not a private address.

**AI meal assistance is marked Experimental**, and that is a claim about stability rather than accuracy: the feature may change or be removed, and the providers and models offered may change with it. It stops being experimental when two things hold — a model has been screened against a real corpus of photographs containing no food ([#719](https://github.com/simonoppowa/OpenNutriTracker/issues/719) ran on five images, only one of them a photograph), and one release cycle passes with no provider or model dropped from the curated list. Until both are true the label stays, so that removing it is something you can check rather than something that felt right.

**Neither test can be run against a server you run yourself**, so the exit condition above is about the three hosted providers and does not cover that path. The project has never seen the model on your machine and there is no curated list for it to be dropped from. What stands in for a screen there is the setup check in Settings: it asks your server to read one meal line and one sample photograph, and reports what came back — so the camera is offered only after a photograph has actually been read once, and stops being offered when your server says it cannot.

**AI meal assistance** is off until you supply your own API key, or the address of a server you run, in **Settings → AI meal assistance** — a server of your own needs an address and a model name, not a key. It can be paused without removing the credential. **Settings → Show AI Features** hides it altogether — the Snap meal tile, the AI badges and the AI meal assistance row — and while it is off nothing is sent to a model, even with a key saved; typed meals are read by the offline parser. Where there is a key, it is held in the Android Keystore / iOS Keychain and never leaves the device except as the request header it authenticates; a server of your own has an address there instead, held the same way. The project never sees either and does not pay for a provider's use. Only the line you type, or a photo you explicitly pick, is sent — never your diary, profile, or history.

**Three providers, and they differ along two axes that do not line up.** Anthropic and OpenAI are reached directly; OpenRouter is a **broker**, so a request touches OpenRouter *and* the vendor serving your chosen model — two destinations, not one. Every curated OpenRouter model is pinned to the vendor named beside it in Settings, with fallbacks off, so that vendor is the one that answered; without a pin a request for a Claude model is routinely served by someone else, which is why the pin exists. The OpenRouter list reaches two vendors — Anthropic and OpenAI — so on that path the vendor is a per-model choice rather than a property of the provider. A key is stored per provider, so switching back does not mean finding a credential again.

Retention cuts the other way. Anthropic states images are not stored beyond the request — with one exception, below. OpenRouter keeps content only to route it, *except as required for abuse detection, security, billing or legal compliance*. And **OpenAI keeps API inputs and outputs for up to 30 days** by default, longer where law requires it or where reasonably necessary to protect its services or a third party from harm. **Being reached directly is not the same as keeping less.**

**On the broker path the two stack**, because a request lands at both destinations: OpenRouter's promise covers OpenRouter's own handling, and the vendor serving your model then keeps what it receives under its own policy. So choosing an OpenAI model through OpenRouter gets OpenRouter's routing promise *and* OpenAI's 30 days — and choosing an Anthropic one gets the ephemerality below, exception included. The serving vendor is named in Settings on every row precisely because it decides this.

**One thing is still unique to the OpenRouter path.** An account-level identity is forwarded to the serving vendor on every request and cannot be switched off — because you hold one key, it works as a stable per-user handle at that vendor. Neither direct path forwards one: OpenAI's `safety_identifier` is documented optional and the app does not send it.

**Reading a meal photo** is the same feature with a camera instead of a keyboard, and is offered once a key or address is enabled — for a server you run, only after the setup check above has read a photograph successfully. The photo is encoded in memory, sent for that one request, and then unreachable — it is never written to the app's documents directory, so it is not in your exports and cannot be shown again. The system photo picker does hand the app a temporary copy in its cache; the app attempts to delete that as soon as the photo is encoded, whether or not the request succeeded — best effort, so on the rare occasion the delete fails the copy stays in the cache until the OS clears it. **On the Anthropic-direct path**, Anthropic's [vision documentation](https://platform.claude.com/docs/en/build-with-claude/vision) states images are *"ephemeral and not stored beyond the duration of the API request"* and are not used to train models. **That default has one exception, stated by Anthropic itself, and it is about retention, not training:** its [retention documentation](https://platform.claude.com/docs/en/manage-claude/api-and-data-retention) states that content flagged by its automated trust-and-safety systems may be retained for up to two years regardless of the ephemeral promise, to enforce its Usage Policy. That sentence — ephemeral, with this exception — is Anthropic's and does not travel: via OpenRouter or OpenAI the applicable promise is the weaker one above, and the two are weaker in different ways.

The model reads *language*, not nutrition: it returns a food name and, when you stated one, an amount. **Every calorie and macro still comes from the food databases below**, so "every number is cited" holds whether or not you enable this. The request carries a tool schema with no nutrition fields ([#633](https://github.com/simonoppowa/OpenNutriTracker/issues/633)), so the model has nowhere to put an estimated calorie count, and whatever it returns is held to the same bounds the offline parser enforces.

From a photo the rule is tighter still: it may **count** what it can see (two eggs, three sausages) but never **measure**. Nothing in a photograph states a weight, so a gram figure read off a picture would be a guess arriving with the same confidence as a number you typed. Any amount that comes back carrying a unit is discarded along with its number, and the row falls to the ordinary default for you to set.

**How it is built** is documented separately. [The AI implementation](docs/ai-architecture.md) walks a typed meal and a photo end to end, maps the request paths, and shows where each rule above is enforced — the nutrition rule, for one, is a single schema constant with no such field in it, re-checked in Dart against a reply that ignored the schema entirely. This section states what the app promises; that page states how it is made to hold, and defers back here wherever the two touch.

[USDA FoodData Central](https://fdc.nal.usda.gov/), the German [BLS](https://www.blsdb.de), INDB and TBCA are where the food *data* comes from, not places your device talks to. Those datasets are ingested into the Supabase backend ahead of time ([self-hosting guide](docs/supabase-self-hosting.md)), so a search reaches that backend and stops there. Settings → Food databases chooses which datasets a search covers. Five are selectable today, with INDB and TBCA in the schema but not yet carrying data ([`sp_const.dart`](lib/features/add_meal/data/dto/sp/sp_const.dart)).

Searches and product lookups to Open Food Facts carry a User-Agent naming the app, platform, and version; photograph downloads do not. Requests to the Supabase backend carry the Supabase SDK's own client headers instead. **The app generates no user or device identifier and sends none** — but a request still arrives from somewhere, and the Supabase gateway logs the address it came from along with a coarse location and a fingerprint of the TLS connection, kept for 24 hours. Search results are cached locally and pruned after 90 days.

**Crash reporting** is off until you enable it, and initializes only in release builds (`_runAppWithSentryReporting` in [`lib/main.dart`](lib/main.dart), reached only when `kReleaseMode && hasAcceptedAnonymousData`; the options are set in `configureSentryOptions`, [`lib/core/utils/sentry_config.dart`](lib/core/utils/sentry_config.dart)). `sendDefaultPii` stays `false`, so no username, email, or IP-derived identity is attached. Disabling it, or deleting your data, closes the SDK immediately.

**Permissions:** camera (barcode scanning, meal photos), photo library (meal photos, exports), notifications (daily reminder, fasting timer), internet (food lookups), receive-boot-completed (re-registering the reminder after a reboot), microphone and speech recognition (dictating a meal on the Describe fields, only after you tap the microphone there; the app records and sends no audio itself, but the platform recognizer may process it on Apple's or Google's servers), and on Android billing and network state (Google Play Billing, for the optional tips on the Support page). Health data — workouts, and on iOS the body fat percentage — is read only if you turn on workout import under Settings → Health sync, which is off by default; the access is read-only, nothing is ever written back to Health Connect or Apple Health, and the imported workouts stay on your device. No location or contacts access.

**Not collected:** no account, email, or phone number. The backend is read with an anonymous key and there is no sign-in path. No advertising ID and no cross-app tracking: `NSPrivacyTracking` is `false` with an empty tracking-domains list, and crash and performance data are declared *not linked to the user* ([`PrivacyInfo.xcprivacy`](ios/Runner/PrivacyInfo.xcprivacy)).

<details>
<summary><b>Verifying APK signatures</b></summary>

If you are side-loading an OpenNutriTracker APK from GitHub Releases, or from F-Droid once the app is published there, you may want to confirm that the file you downloaded was signed by the same key used for every official release, rather than by someone who intercepted the download or repackaged the app.

The official SHA256 fingerprint of the Android release signing certificate is:

```
SHA256: 84:E8:60:74:EC:7E:DA:BB:10:F2:01:79:86:DD:F0:9E:53:1C:AF:7A:73:08:0A:C1:17:2B:80:C4:9C:62:08:27
```

To verify a downloaded APK against that fingerprint, run:

```sh
apksigner verify --print-certs /path/to/opennutritracker.apk
```

The `SHA-256` line in the output should match the value above exactly.

</details>

## Building

Same toolchain as upstream (Flutter 3.44.6 via [FVM](https://fvm.app/), JDK 17, Android SDK 36):

```sh
cp .env.example .env              # placeholders are fine for a local build
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter build apk --flavor develop --debug

# iOS, unsigned (CocoaPods; Swift Package Manager off, as upstream's CI does)
fvm flutter config --no-enable-swift-package-manager
fvm flutter build ios --release --flavor develop --no-codesign
```

Releases use the `develop` flavor (label **ONT+**, package `….opennutritracker.develop`)
signed with the fork's release key via `android/key.properties`, which is not in the repository.

## Credits and license

The ONT+ additions are by **Marcell Marko** ([@MCsumz](https://github.com/MCsumz)). ONT+ is built on [OpenNutriTracker](https://github.com/simonoppowa/OpenNutriTracker) by
[@simonoppowa](https://github.com/simonoppowa) and its contributors; nearly all of the app is their work. Upstream's original README
is kept in [docs/upstream-README.md](docs/upstream-README.md).

Like the original, ONT+ is licensed under the [GNU GPLv3](LICENSE). It is not affiliated with
or endorsed by the OpenNutriTracker project — please report issues with the changes above here,
not upstream.

Nutrition information is for general guidance only and is not medical advice.
