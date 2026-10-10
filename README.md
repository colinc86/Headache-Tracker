# Headache Tracker

A private, on-device headache diary and forecast for iPhone and Apple Watch.

Log a headache in one tap, and the app learns from your own history, Apple Health readings, and the weather to forecast your chance of a headache in the next 24 hours. It then shows which of your signals tend to come before your headaches. Everything (storage, model training, prediction, and the written summaries) runs on your device. There is no backend.

## Features

**Track**
- A live 24-hour forecast as a calibrated percentage ("of 100 days like today, about 42 bring a headache"), with its likely range, the model's track record, and a confidence grade.
- A one- or two-sentence explanation written on device by Apple Intelligence, with a built-in fallback.
- A ribbon showing the last two days of forecasts flowing into the next 24 hours.
- "Behind Today's Risk": each signal moving today's forecast, against your usual value.
- A Today card with your headache-free streak and the last two weeks at a glance.
- A log bar pinned above the tab bar: None, Present, Mild, Moderate, Severe, and Resolve, always one tap away.

**Profile**
- A signature glyph showing which signal areas (sleep, heart, weather, activity…) lead your headaches.
- A written portrait of your patterns.
- Your triggers inline, each with its data, lead time, and confidence. These are associations in your own data, not causes.
- A rhythm clock of when headaches start (hour × weekday), the shape of a typical headache, what helped, your month, and how honest the forecast's percentages have been.

**Headaches**
- An overview of the chosen period (count, rate and trend, average length, days affected), with severity, onset, and duration charts.
- The full log, with detail, editing, notes, tags, and medications with efficacy ratings.

**Everywhere else**
- Widgets: Outlook, Twin Ring, Horizon, Signals, Risk Clock, and a severity logger, plus Lock Screen and StandBy.
- A Live Activity for an in-progress headache.
- An Apple Watch app with complications.
- Siri shortcuts, actionable notifications, a morning brief, a "What if…" simulator, a clinician PDF/CSV export, and optional iCloud sync to your private database.

## How the forecast works

- **Inputs.** Each sample combines HealthKit metrics (sleep, HRV, resting heart rate, respiratory rate, temperature, activity…), WeatherKit station data, and time of day. Trailing-window statistics are computed over fixed clock windows, and readings are standardized against your own 14-day baseline.
- **Model.** One CreateML boosted-tree classifier, regularized for small personal datasets and trained on device in a nightly background task. It is evaluated with a forward-chaining rolling-origin scheme that never trains on the future, then Platt-calibrated on the out-of-fold scores.
- **Uncertainty.** A small bagged ensemble supplies a plausible range for each forecast. The confidence grade combines that range with how many of your signals were actually measured.
- **Insights.** A separate, transparent correlation engine (point-biserial and Spearman, permutation p-values, Benjamini–Hochberg FDR, confounder checks) finds personal trigger patterns.
- **Written summaries.** Apple's Foundation Models framework rewrites a small sheet of pre-computed facts. It never sees raw data. Every response is validated, and any number or signal not in the facts, advice, or diagnosis wording sends it back to the built-in wording.

The forecast is a personal pattern tool, not medical advice.

## Requirements

- Xcode 27 or later.
- iOS 26 or later; watchOS 10 or later for the watch app.
- An iPhone for anything involving the model. CreateML is unavailable on the simulator, where a deterministic stub predictor stands in.
- Apple Intelligence for generated summaries (optional; the app falls back to built-in wording).

## Building

```sh
git clone git@github.com:colinc86/Headache-Tracker.git
open "Headache Tracker.xcodeproj"
```

Build the **Headache Tracker** scheme. Swift packages resolve in Xcode.

> **Note:** the `DataController` package (the Core Data stack) is currently referenced from a local path, `../../Packages/DataController`, at v1.4.0. That version isn't on GitHub yet. Until it is pushed and the package reference points back at [`colinc86/DataController`](https://github.com/colinc86/DataController), a fresh clone needs that package checked out at the local path.

Signing needs the HealthKit, WeatherKit, iCloud (CloudKit), Push Notifications, and App Group (`group.com.cnc.Headache-Tracker.contents`) capabilities on your team.

## Testing

```sh
# Unit tests (statistics, calibration, correlation engine, forecasting math, summaries…)
xcodebuild -project "Headache Tracker.xcodeproj" -scheme "Headache Tracker" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Headache TrackerTests" test

# Screenshot sweep: seeds representative data and captures every screen
xcodebuild -project "Headache Tracker.xcodeproj" -scheme "Headache Tracker" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Headache TrackerUITests/ScreenshotSweepTests" test
```

## Project layout

| Path | Contents |
| --- | --- |
| `Shared/` | Model layer shared by the app and widgets: Core Data, HealthKit, weather, the ML pipeline (`Models/Prediction/`), the correlation engine (`Models/Statistics/Correlation/`), design system and shared views |
| `Headache Tracker/` | The app: Track, Profile, and Headaches tabs, written summaries (`Models/Summaries/`), background refresh, notifications, export |
| `Headache Tracker Widget/` | Widgets and Live Activities |
| `Headache Watch App/`, `Headache Watch Widget/` | The watch app and complications |
| `Headache TrackerTests/`, `Headache TrackerUITests/` | Unit tests and the screenshot sweep |

`CLAUDE.md` documents the architecture, invariants, and conventions in depth.

## Privacy

Your data stays on your device. iCloud sync is off by default; when you turn it on, only your own headache records go to your private iCloud database. Model training data, predictions, and generated summaries never leave the phone.
