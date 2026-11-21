# My Closet

A Flutter wardrobe app with real AI clothing analysis and on-device
persistence. Built as the P0 scope of `my-closet-implementation-plan-v2.md`.

**Read this first:** this project was written without a Flutter SDK available,
so it has never been compiled. The structure, imports and cross-file
references were verified programmatically, but expect to fix a small number of
compile errors on first build — most likely API drift in a package version
newer than the code assumes. The Troubleshooting section covers the failures I
consider most likely and what to change.

---

## 1. Requirements

| Need | Version |
|---|---|
| Flutter SDK | 3.24 or newer (uses Material 3 `surfaceContainer*` roles) |
| Dart | 3.4+ (comes with Flutter) |
| Android Studio | any recent version, with the Flutter and Dart plugins |
| JDK | whatever your Android Studio bundles |
| Gemini API key | optional — see §4. The app runs without one, but analysis requires it |

Check your install first:

```bash
flutter --version
flutter doctor
```

---

## 2. Setup

The project ships **source only**: `lib/`, `test/`, `assets/`, `pubspec.yaml`.
The `android/` and `ios/` folders are generated locally, because platform
scaffolding is specific to your machine and SDK version.

### Option A — the script (macOS / Linux / Git Bash)

```bash
cd my_closet
chmod +x setup.sh
./setup.sh
```

It generates the platform folders, runs `flutter pub get`, then `flutter
analyze` and `flutter test`.

### Option B — manual (any OS, including Windows PowerShell)

Do **not** run `flutter create .` inside this folder — it can overwrite
`lib/main.dart`. Generate a throwaway project and copy only the platform
folders across:

```bash
# 1. From the folder that CONTAINS my_closet:
flutter create --project-name my_closet --org com.example --platforms=android,ios _shell

# 2. Copy the platform folders in (PowerShell: use Copy-Item -Recurse)
cp -R _shell/android my_closet/android
cp -R _shell/ios     my_closet/ios

# 3. Clean up and install
rm -rf _shell
cd my_closet
flutter pub get
```

### Then, in Android Studio

1. **File → Open** and select the `my_closet` folder (the one with
   `pubspec.yaml`). Do not open a parent folder.
2. Wait for "Pub get" to finish in the status bar.
3. Pick a device in the device dropdown — an emulator or a plugged-in phone.
4. Press **Run** (the green ▶).

First build takes a few minutes while Gradle downloads. Later builds are fast.

---

## 3. What you should see

On first launch the app seeds 35 wardrobe items, 7 saved outfits and a few
planner entries into local storage, then shows signup.

The fast path through everything:

1. **Sign up** — any valid details. Try `taken@example.com` to see the
   duplicate-email failure, or any address containing `network` to see a
   transport failure. Validation is real; the account is local.
2. **Onboarding** — 5 steps. Styles and colours here directly weight
   recommendations, so pick a few. Steps 2–5 are skippable.
3. **Wardrobe tab** — 35 seeded items. Search, filter by category, open the
   filter sheet for colour/occasion/season and sorting.
4. **Add item** → **Analyze with AI** — the graded AI feature. Needs a photo
   (see §4 for getting one onto an emulator) and ideally an API key.
5. **Style tab → What should I wear?** — pick Work, drag the temperature
   slider, press Generate. Open **Score detail** on the result to see the
   points behind each explanation line.
6. **Any item → Find Matches / Build Outfit** — the anchor item stays fixed.
   In Build Outfit, **Replace** re-solves one slot and leaves the rest.
7. **Planner tab** — assign saved outfits to days.
8. **Profile tab** — shows live AI status, and has **Reset demo data** for a
   clean slate between demos.

Items with no photo render as a colour swatch plus a category icon. That is
intentional — no fake stock photos ship with the project, and real photos
appear as soon as you add them.

---

## 4. Enabling Gemini AI

Clothing analysis always uses the Gemini service. Without a key, or if the
request fails, the app displays an error and does not invent a suggestion.

### Get a key

Free, from [Google AI Studio](https://aistudio.google.com/apikey).

### Run with it

```bash
flutter run \
  --dart-define=GEMINI_API_KEY=YOUR_KEY_HERE \
  --dart-define=GEMINI_MODEL=gemini-3.8-flash
```

### In Android Studio

**Run → Edit Configurations → Additional run args**:

```
--dart-define=GEMINI_API_KEY=YOUR_KEY_HERE --dart-define=GEMINI_MODEL=gemini-3.8-flash
```

Confirm it took effect on the **Profile** tab — the AI card shows **Live**
plus the model name.

### Which model

`AppConfig.geminiModel` defaults to `gemini-3.8-flash`, which is what Google's
image-understanding docs demonstrate. Two things worth knowing:

- Gemini model names turn over quickly. **Confirm the current image-capable
  Flash model at <https://ai.google.dev/gemini-api/docs/models> before a
  demo** and override `GEMINI_MODEL` if it has moved.
- The `gemini-2.5-*` family that most tutorials use is now access-limited to
  accounts that used it previously. New keys should use a 3.x model.

### Getting a clothing photo onto an emulator

The AI step needs a real photo. Easiest options:

- Drag a JPEG from your desktop onto the running emulator window — it lands
  in the emulator's gallery.
- Or use the emulator's camera pointed at its synthetic scene (poor results,
  but proves the pipeline).
- Or run on a physical device and photograph an actual garment. Best demo.

### Security — stated plainly

A key passed via `--dart-define` is **compiled into the app and can be
recovered from an APK**. That is acceptable for a course prototype and not for
production. The production fix is a server-side proxy, or Firebase AI Logic
(`firebase_ai`), which keeps the key off the client entirely. This limitation
is deliberate and documented rather than hidden — it is good material for the
paper's ethics section.

`.gitignore` excludes `.env` and `run_local.sh`. **Never commit your key.**
See `.env.example`.

---

## 5. Testing

```bash
flutter test
```

| File | Covers |
|---|---|
| `test/recommendation_test.dart` | Scoring, including the plan's worked example: an appropriate outfit must outscore shorts at 52°F in the rain. Also anchor invariants, replace-slot behaviour, determinism |
| `test/color_rules_test.dart` | Symmetry, the plan's colour table, clash penalties |
| `test/gemini_ai_service_test.dart` | Response parsing across four API shapes, vocabulary enforcement, every failure path. **No test touches the network** |
| `test/persistence_test.dart` | Hive round-trips, including close-and-reopen — the test an in-memory store would fail |
| `test/models_test.dart` | JSON round-trips, defensive parsing, slot exclusivity |
| `test/widget/` | Signup validation, wardrobe filtering, the AI suggestion card's accept/dismiss/unavailable paths |

The recommendation test is the one worth pointing at in the paper: it is only
writable because the engine is deterministic. A model-backed recommender could
not be asserted this way.

---

## 6. Architecture

```
lib/
├── app/          theme, router, 5-tab shell
├── core/         config (dart-define), controlled vocabulary, shared widgets
├── models/       hand-written immutable models (no codegen)
├── repositories/ abstract interfaces — the only thing the UI knows about
├── data/
│   ├── local/    Hive implementations (production path) + seed loader
│   └── memory/   in-memory implementations (test doubles)
├── services/     AI, weather, recommendation engine, scoring config
├── providers/    Riverpod wiring — the only place implementations are named
└── features/     one folder per journey
```

The rule the whole thing is built on: **widgets depend on service interfaces,
not concrete implementations.** Gemini is selected for clothing analysis;
the mock AI service is used only in tests.

```
WardrobeRepository (abstract)        AiService (abstract)
        ↓                                    ↓
HiveWardrobeRepository               GeminiAiService  ← real HTTP
InMemoryWardrobeRepository           MockAiService    ← tests only
        (tests)
```

### Deliberate decisions worth defending in the paper

**No code generation.** Models are hand-written with `fromJson`/`toJson`
instead of `freezed` + `json_serializable`. The project therefore builds after
`flutter pub get` with no `build_runner` step. The cost is boilerplate; the
benefit is one less thing to break on a teammate's machine the night before a
demo.

**`hive_ce`, not `hive`.** The rubric names Hive, but the original `hive`
package is abandoned — its author stopped maintaining both Hive and Isar.
`hive_ce` is the maintained community continuation. Adding `hive: ^2.2.3` would
mean shipping an unmaintained dependency.

**Boxes store JSON strings.** This removes `hive_ce_generator` and its
`TypeAdapter`s entirely. The cost is that Hive cannot query inside records, so
filtering happens in Dart — irrelevant at 35 items, a real limitation at
10,000. `drift` would be the better engineering answer for the wardrobe's
filter/sort workload; it costs more setup and codegen time. That trade-off is
Data Storage section material.

**The recommendation engine is deterministic Dart, not an LLM.** AI is spent
where a model has a genuine advantage — visual classification — and not on
constraint scoring, which rules do better. This buys testability (§5) and
explanations that trace to specific rules rather than model narration. Every
line in "Why this works" is gated on a scoring dimension that actually fired,
which is why **Score detail** can show the exact points behind it.

**Raw HTTP, not a Google SDK.** `google_generative_ai` is deprecated in favour
of Firebase AI Logic, which needs a Firebase project — cloud infrastructure in
an otherwise backend-free prototype. A ~100-line REST client keeps the
dependency surface at `http` and makes the integration readable in one file.

**The AI response parser is tolerant on purpose.** Google replaced
`:generateContent` with `/v1beta/interactions` for new projects, and the raw
REST response shape is not fully documented — the SDKs expose `output_text` as
sugar over an `outputs` array. `GeminiAiService.extractText` tries four shapes
including the legacy one. When the API moves again, the suggestion card's
**Technical details** panel shows the raw body, so the fix is a one-line
change.

**Weather stays mocked.** The rubric does not require a weather API, and
switchable presets demo *better* than a live one — you can show cold-weather
recommendations in July.

---

## 7. What is real and what is mocked

| Concern | Status |
|---|---|
| Clothing analysis | **Real** — Gemini Interactions API; errors are shown, never replaced with canned results |
| Data storage | **Real** — `hive_ce` on-device, survives restart |
| Photo capture | **Real** — `image_picker`, copied into app documents dir |
| Recommendation engine | **Real** — deterministic Dart, by design not an LLM |
| Authentication | Mocked (`MockAuthRepository`), with enumerated failures |
| Weather | Mocked (`MockWeatherService`), 4 presets, user-editable |
| Backend / cloud storage | None, by design |

---

## 8. Troubleshooting

**`Error: Couldn't resolve the package 'hive_ce'` or the import fails**
Try `package:hive_ce/hive.dart` instead of `package:hive_ce/hive_ce.dart` in
`lib/data/local/hive_boxes.dart`, `hive_repositories.dart`,
`mock_auth_repository.dart` and `test/persistence_test.dart`. The API is
identical; only the barrel file name varies between versions.

**Compile errors about `surfaceContainer`, `surfaceContainerLow` or
`surfaceContainerHighest`**
Your Flutter predates 3.22. Either upgrade (`flutter upgrade`) or replace those
with `surfaceVariant` in `lib/app/theme.dart` and the widget files.

**AI analysis reports that no API key is configured**
Pass `--dart-define=GEMINI_API_KEY=...` in *Additional run args* in Android
Studio, not as an environment variable. Full restart, not hot reload:
`--dart-define` is compile-time.

**AI returns `HTTP 404 ... model name`**
The model name has moved. Get the current image-capable Flash model from
<https://ai.google.dev/gemini-api/docs/models> and pass it as
`--dart-define=GEMINI_MODEL=...`.

**AI returns `HTTP 400 ... may not accept image input`**
You picked a text-only or audio-only variant. Pick a Flash model the
image-understanding docs demonstrate.

**AI returns "Could not find generated text in the response"**
The API shape changed again. Open **Technical details** on the suggestion card
to see the raw body, then add that shape to
`GeminiAiService.extractText` — it is a short, isolated function built for
exactly this.

**Camera or gallery does nothing on iOS**
Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Take photos of your clothes to add them to your wardrobe.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Choose photos of your clothes to add them to your wardrobe.</string>
```

Android needs no manifest changes — `image_picker` uses system intents.

**Gradle or Android licence errors on first build**
`flutter doctor --android-licenses`, then rebuild.

**Seed data looks wrong, or you want a clean demo**
Profile tab → **Reset demo data**.

---

## 9. Rubric traceability

| Requirement | Where |
|---|---|
| Clean, responsive Flutter UI | `lib/app/theme.dart`, `lib/core/widgets/common.dart`; grid uses `SliverGridDelegateWithMaxCrossAxisExtent` so it reflows by width |
| At least three functional screens | Twelve. Wardrobe, Add/Edit Item, Item Detail, What Should I Wear, Match/Build, Outfit Builder, Saved Outfits, Planner, Profile, Edit Profile, Signup, Onboarding |
| Consistent state management | Riverpod throughout; `lib/providers/providers.dart` is the only place implementations are named |
| Local or cloud data storage | `hive_ce`, `lib/data/local/`; asserted by `test/persistence_test.dart` |
| Clear, intuitive user flow | Signup → Onboarding → Wardrobe → Add Item → Recommend → Save → Plan |
| AI integration, visible and functional | `lib/services/gemini_ai_service.dart`, surfaced as **Suggested Details** in Add Item |
| Approved AI source | Google Gemini API (Interactions) |
| AI relevant to the app's purpose | Removes the main friction in any wardrobe app: hand-tagging every garment |
| Paper §B Technical Architecture | §6 above |
| Paper §C AI Integration Analysis | §4 and §6 above; ethics in `gemini_ai_service.dart` doc comment and `AiDisclosureDialog` |
| Paper §E Evaluation | §5 test results, plus the stated limitations in §6 |

---

## 10. Honest limitations

Worth writing up rather than hiding — the specific ones are better paper
material than generic ones:

- **Never compiled.** See the note at the top.
- **API key ships in the binary.** §4.
- **Colour rules are not fashion science.** They demonstrate the architecture.
  `ColorRules` is a legible, arguable table rather than an opaque score.
- **Hive cannot query inside records.** Filtering is O(n) in Dart.
- **Material is the model's least reliable field.** It is inferred from visual
  texture; the model cannot feel fabric. The prompt asks it to prefer `null`,
  and the accept/modify gate means a wrong guess costs a tap.
- **Expect degraded AI accuracy** on non-Western garments, handmade or altered
  clothing, and colour calls on very dark or sheer fabrics where lighting
  dominates. Test against such items deliberately and report what you find — a
  measured failure case is worth more than a disclaimer.
- **Feedback adjustment is capped at ±5 points.** Without a ceiling,
  accumulated likes collapse the engine into one outfit forever.
- **No photo for a seeded item.** Swatches stand in. Add real photos to see
  the image path.
