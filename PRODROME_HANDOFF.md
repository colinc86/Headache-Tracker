# Handoff: Prodrome-sensitivity upgrades for the risk predictor

**Audience:** an engineering session working in this repo (Headache Tracker).
**Read first:** `CLAUDE.md` in this repo — it documents the architecture, the ML pipeline, and the invariants you must not break. This document assumes it.

## Context (what already exists)

This app is **already a migraine-prediction app**. It runs an on-device CreateML boosted-tree
classifier that produces a calibrated *"risk of a headache within the next 24h"* from weather,
barometric pressure, HealthKit metrics, and time-of-day, with Platt calibration, a personal-baseline
correlation/insights engine, background retraining, two widgets, a Live Activity, and a morning brief.

**This is not a "build prediction" task.** It is about making the *existing* model **prodrome-sensitive**
and giving it **better inputs**. Do not rebuild the pipeline.

## Scientific framing (why these changes)

The migraine prodrome is an **autonomic shift against the person's own baseline** in the hours before
onset — HRV drop / sympathetic swing, skin-temperature change, sleep disruption, lethargy. Two
consequences drive the work below:

1. **Raw values under-carry the signal.** The model currently feeds autonomic metrics (HR, HRV, resting
   HR, respiratory rate) mostly as raw windowed values. The prodrome lives in **deviation from personal
   rolling baseline** and **rate of change**, not absolute level. The correlation engine already computes
   personal rolling z-scores (`Shared/Models/Statistics/Correlation/`, winsorized at |z|=6); the ML
   feature providers should consume that same representation.
2. **Signals that are captured/available but not modeled.** Menstrual-cycle phase and skin temperature are
   strong, physiologically-motivated inputs that the model can't currently see.

## Data-source status (as of this handoff)

| Signal | Source | In HealthKit? | Consumed by model? | Action |
|---|---|---|---|---|
| HR, resting HR, walking HR | Apple Watch | yes | yes | none |
| HRV (SDNN, all-day) | Apple Watch | yes | yes | none |
| **HRV beat-to-beat (IBIs)** | Apple Watch | yes — `HKHeartbeatSeriesSample` | **no** | **add (P1)** |
| **Skin/body temperature (30-min)** | R09 ring via **Therma app** → HealthKit `bodyTemperature` | **yes, flowing now** | **no** | **add read + feature (P0)** |
| **Menstrual cycle** | HealthKit | yes | stored in `HealthData`, **not in ML providers** | **add (P0)** |
| Respiratory rate, SpO₂, sleep, steps, mindfulness, audio, hydration, caffeine, daylight, exercise | Apple Watch / HealthKit | yes | partially | see P1 |
| Peripheral perfusion / vasomotor tone | would need **raw PPG** | no | no | **deferred** (see bottom) |
| EDA (electrodermal) | no consumer source on Watch/R09 | no | no | **out of scope** |

## Work items (prioritized)

### P0 — cheap, high-value, all in-ecosystem

1. **Skin/body temperature, end to end.** Therma already writes the R09's 30-minute temperature to the
   HealthKit `bodyTemperature` type, so the source is live.
   - Add read support in `Shared/Models/HealthKit/HealthKitData.swift` for
     `HKQuantityTypeIdentifier.bodyTemperature` (consider also `appleSleepingWristTemperature` and
     `basalBodyTemperature` for Apple Watch users).
   - Add a field to the `HealthData` entity (model `Headache_Tracker 2.1`), assigned to the **Local**
     store configuration; wire its **presence bit** in `presentMetrics` (never zero-fill absence).
   - Expose it through a feature provider under `Shared/Models/Prediction/Inputs/`.
   - Add a `Preferences.Predictors` toggle + `isCollectionEnabled` gate.

2. **Menstrual-cycle features into the model.** `menstrualDaysSinceCycleStart` and `menstrualFlowActive`
   are already on `HealthData` but are not in the four ML `Inputs/*` providers. Add them (likely
   `UncontrolledUserInput`). Reuse the existing **deferred** menstrual HealthKit authorization (already
   requested when the toggle is enabled). Add a `Preferences.Predictors` toggle.

### P1 — the core scientific upgrade

3. **Personal-baseline-relative autonomic features.** In addition to raw values, feed rolling **personal
   z-scores** and **short-window slopes** (e.g., last 6h vs 14-day baseline) for HRV, resting HR,
   respiratory rate, sleep, and temperature. Reuse the baseline math in
   `Shared/Models/Statistics/Correlation/`. Hard constraints:
   - Baselines must be **causal** — computed only from past data, no future leakage.
   - Persist the baselines alongside `FeatureMedians` so inference uses the same baseline it trained on.
   This is the single highest-leverage change for prodrome sensitivity.

4. **Richer HRV from `HKHeartbeatSeriesSample`.** Apple never exposes the raw PPG waveform, but it *does*
   expose **beat-to-beat inter-beat intervals** via `HKHeartbeatSeriesSample` / `HKHeartbeatSeriesQuery`
   (recorded during the Watch's background HRV/Breathe measurements — intermittent, a handful per day).
   From the IBIs, compute **RMSSD**, **pNN50**, and **frequency-domain (LF/HF)** HRV — the
   parasympathetic-dominant measures the single SDNN value throws away. Add these as `HealthData` fields
   (Local config, presence-gated) and feed them through the baseline-relative representation from item 3.

5. **Consider a shorter prediction horizon.** The current label is onset within a rolling **24h** window
   (`deriveLabels(from:)` in `TrainingData+Extensions.swift`). A prodrome model benefits from a tighter
   horizon (6–12h) where autonomic precursors are strongest. Add it as an **additional** label/output,
   don't replace the 24h one.

## Guardrails — do not violate (from `CLAUDE.md`)

- **Dual-compile rule.** CreateML is device-only. Any change to the `Predictor` public API must be mirrored
  in `TestPredictor.swift`, and likewise for `Model.swift`, `TrainingInput.swift`,
  `MLDataTable+Extensions.swift`, and the `Outputs/*` types — or simulator builds break.
- **Schema versioning.** Adding features requires bumping `Constants.modelSchemaVersion` (currently 3) and
  `trainingDataVersion`; `upgradeTrainingData()` back-fills existing rows.
- **Store-config boundary.** New `HealthData` fields belong to the **Local** configuration in model 2.1;
  relationships must never cross the Cloud/Local split.
- **Presence bitmasks.** Set the bit on write, gate on read; **absent ≠ zero**. Never zero-fill missing
  data — it corrupts the median-imputation pipeline.
- **Write fan-out.** `HeadacheManager` write methods mirror to HealthKit + shared widget defaults + the
  training pipeline; keep all three in sync.

## Validation guardrails

- Attacks are rare → heavy class imbalance. Evaluate with **precision/recall, Brier, and calibration**,
  not accuracy. (The app already does chronological 80/20 + Platt calibration + `Evaluation` tracking.)
- Validate new features **within-subject** and confirm baselines are computed **causally** (no future
  leakage). This is the easiest way to fool yourself into a great-looking, useless model.

## Deferred / out of scope (with rationale)

- **Raw PPG / R09 over Bluetooth.** Investigated and parked. The R09 speaks the standard Colmi
  Nordic-UART protocol (`6E40FFF0…`, write `…0002`, notify `…0003`, 16-byte checksummed packets). Its
  real-time command (105) returns **computed values** (HR number, SpO₂ number), and there is **no
  documented raw-PPG-waveform command** — raw optical capture would be a real reverse-engineering spike,
  likely only intermittent (rings don't buffer waveforms all day), and HealthKit has no raw-PPG type so it
  would need a side-channel bridge that breaks the clean "everything via HealthKit" architecture. Probe
  scaffolding is saved at `/Users/colin/Local Documents/Programming/r09-probe`.
- **Peripheral perfusion / vasomotor tone.** The one prodrome-relevant signal that genuinely needs raw
  PPG. Blocked by the above; only pursue after a spike proves it adds predictive lift over the
  heartbeat-series HRV + temperature work.
- **EDA (electrodermal activity).** No consumer source (neither Apple Watch nor R09 exposes it). Out of
  scope unless a Fitbit Sense-class device enters the picture.
