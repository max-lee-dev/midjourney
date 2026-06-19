# Midjourney Medical — Vision

> *Just sound and water and 60 seconds.*

This repo is a **patient-facing iOS prototype** for what happens *after* a full-body Ultrasonic CT scan — the software layer that turns raw imaging into something a person can understand, track, and act on over time.

The product vision below comes from the [Midjourney Medical announcement](https://midjourney.com/medical). The prototype in this folder explores one slice of that future: **what your body looks like in an app when you can scan it every few months.**

---

## The Big Vision

Midjourney Medical is a new division of Midjourney focused on a radical reimagining of healthcare through a new form of medical imaging called **Ultrasonic CT** — also called **the full-body ultrasound**.

### What Ultrasonic CT is

| Property | Ultrasonic CT | Traditional MRI |
|---|---|---|
| Scan time | ~60 seconds | 30–60+ minutes |
| Radiation | None | None |
| Magnetic fields | None | Powerful, claustrophobic |
| Medium | Sound + water | Magnets + radio waves |
| Ambition | Whole-body, serial, routine | Targeted, episodic, clinical |

Ultrasonic CT aims for whole-body imaging that is in many ways **superior to MRI**, but fast enough to become a **routine habit** rather than a rare event.

The guiding metric is *"megabytes per second per dollar"* — as much information about your body, as quickly and as cheaply as possible — so that imaging can move from a rare clinical event to a casual, "whenever you want" habit.

### The scanner: a pool of golden light

You don't lie in a magnet. You **step into a shallow pool of golden light** and a platform on rails lowers you into the water at about **5 cm/second**.

- As you descend, you pass through a ring of **~500,000 tiny elements**, each the size of a grain of sand and each able to act as **both a speaker and a microphone** — *"a choir and an audience."*
- Each element sends ultrasonic waves and listens to the ripples coming back, **like a dolphin using echolocation**, from every angle.
- Waves change shape as they cross boundaries in **density and stiffness** (water → skin → fat → muscle → bone). Reconstructing those changes turns sound into a detailed image.
- The data is enormous: **terabytes per second** — roughly **500 hours of HD video for every 1 second of scan** — streamed to a compute cluster that turns waves into a sub-millimeter 3D map of the body, at nearly **100× the speed of MRI**.

You go into the water, you come out of the water, and you're done — in about **60 seconds**.

### Scale & deployment

- **~50,000 scanners** deployed worldwide by ~2031
- **1 billion full-body scans per month** across the fleet — enough for regular, monthly scans for a billion people
- A global sensor network — not a handful of hospital machines
- The ambition: with enough early imaging, help the world **avoid ~30% of deaths and ~50% of healthcare costs**

### First location: Midjourney Spa (San Francisco, end of 2027)

The flagship is not a hospital waiting room. It is a **health spa**:

- Hot tubs, saunas, cold plunges, and cozy rooms with **pools of golden light** that softly scan your body
- A place you'd want to go **even if there were no scanner** — open 24/7, alone or with friends
- Scanning woven into a wellness ritual, not bolted onto acute care

The key reframe: **the scan is a side-effect.** You barely think about it while you're there — but you walk out with another layer added to a living library of your health.

---

## What This Repo Is

```
midjourney/
├── MidjourneyMedical/          # SwiftUI iOS app (prototype)
│   ├── Views/                  # Five main screens + scan loading
│   ├── Models.swift            # Health metrics, scans, body regions
│   ├── MockData.swift          # Coherent 2-year demo narrative
│   ├── BodyScene.swift         # 3D point-cloud body visualization
│   └── Theme.swift             # Design tokens
└── MidjourneyMedical.xcodeproj
```

This is **not** the scanner firmware, the imaging pipeline, or clinical infrastructure. It is the **companion experience** — the interface a spa member opens on their phone to explore what their body is doing.

Everything runs on **mock data** today. The architecture is shaped so real scan payloads can replace `MockData` without rewriting the UI.

---

## The Product Thesis

If you can scan your whole body in 60 seconds, as often as you visit the gym, health stops being:

- A single PDF from a radiologist once every few years
- A blood panel that lags anatomy by months or years
- A crisis discovered too late

And starts being:

- A **longitudinal record** of your body over time
- A **personal baseline** compared to people like you
- **AI-surfaced findings** ranked by what actually matters right now
- A **spatial map** you can tap and explore, not a stack of DICOM slices

The prototype asks: *what does that feel like in your pocket?*

---

## What We've Built

### Launch: Scan Loading (`ScanLoadingView`)

The app opens with a cinematic **full-body scan acquisition** — 100 cross-sectional slices stack into a 3D volume, organs are analyzed, and percentile standings tick in live.

This mirrors the real-world promise: you step out of the scanner and within seconds the data is being processed. The loading screen is both functional (future: real progress from the pipeline) and narrative (the "wow" moment).

Phases: `Initializing → Acquiring → Stacking → Analyzing → Complete`

### Tab 1 — Body (`BodyView`)

A **3D point-cloud figure** on a pure black canvas. Eight tappable anatomical regions, each color-coded by clinical status:

| Region | Metric |
|---|---|
| Brain & Vessels | Arterial stiffness (pulse-wave velocity) |
| Heart | Resting heart rate |
| Lungs | VO₂ max |
| Liver | Hepatic fat fraction |
| Kidneys | Hydration (tissue water) |
| Abdomen | Visceral fat volume |
| Skeletal Muscle | Lean muscle mass |
| Skeleton | Bone mineral density |

Prompt: *"Where do you notice a physical sensation?"* — health as something you **feel in space**, not read in a table.

### Tab 2 — Timeline (`TimelineView`)

Longitudinal charts for every metric across all scans, with a **cohort baseline band** overlaid. Pick a metric, scrub through visits, see the slope.

This is the core loop Ultrasonic CT enables: **serial imaging** that makes trends visible years before conventional bloodwork might.

### Tab 3 — Compare (`CompareView`)

*"Your body has a git diff."* Pick any two scans and see per-metric deltas side by side.

Designed for the moment someone asks: *"Did that bulk actually work? Did my visceral fat come with the muscle?"*

### Tab 4 — Insights (`InsightsView`)

AI-surfaced findings ranked by **significance** — not a flat list of numbers, but narrative cards with severity, trend direction, and anatomical context.

Example from the demo data: visceral fat rising 66% over six scans while muscle and VO₂ improve — the kind of cross-metric story that only emerges when you have repeated whole-body reads.

### Tab 5 — Baseline (`BaselineView`)

**Me vs. cohort** — where you fall in your age/sex distribution for each metric (demo cohort: Males 18–24). Percentile markers on distribution bars.

Ultrasonic CT at scale means enormous reference populations. "Normal for you" becomes "normal for people *like* you" — continuously updated.

---

## Data Model (Prototype)

```
Scan
 └── MetricSample[]          # 8 metrics per scan
      ├── value              # measured this visit
      ├── baseline           # cohort reference
      └── status             # normal · watch · flagged

BodyRegion (8)  ←→  HealthMetric (8)   # 1:1 mapping
Insight                       # AI finding with significance score
CohortBaseline                # percentile position
OrganScanResult               # post-scan "Wrapped" reveal per organ
```

The demo narrative follows a **19-year-old male on a lean bulk** over ~2 years (6 scans):

- Muscle mass, VO₂, resting HR → improving
- Visceral fat → quietly climbing, eventually flagged
- A realistic story where gains and drift coexist

---

## Design Language

- **Canvas:** pure black — open, calm, clinical without being cold
- **Accent:** warm **gold (`#FFB800`)** — this is *"the pool of golden light"* you descend into, not hospital beige. (Implemented in `Theme.swift`.)
- **Scan-flow backdrops:** a "golden pool" gradient with gentle water-caustic motion — you should feel like you're standing in the light
- **Type:** soft white, sharp HUD geometry, generous letter-spacing
- **Status scale:** green (normal) · gold (watch) · red (flagged)
- **Surfaces:** translucent cards with hairline gold strokes — depth without clutter

The aesthetic should feel like a **Midjourney product**, not a patient portal from 2014.

---

## How This Connects to the Spa

```
┌─────────────────────────────────────────────────────────┐
│  Midjourney Spa (SF, 2027)                              │
│  ┌──────────┐  hot tub · sauna · cold plunge            │
│  │ Scanner  │  60-second Ultrasonic CT                  │
│  └────┬─────┘                                           │
│       │ raw volume + derived metrics                    │
│       ▼                                                 │
│  Cloud pipeline (future)                                  │
│  · slice reconstruction                                 │
│  · organ segmentation                                   │
│  · metric extraction                                    │
│  · cohort comparison                                    │
│  · AI insight generation                                │
│       │                                                 │
│       ▼                                                 │
│  This app (prototype)                                   │
│  · scan loading / reveal                                │
│  · body map · timeline · compare · insights · baseline  │
└─────────────────────────────────────────────────────────┘
```

At the spa, the scan is the **atomic unit of the visit**. The app is how that unit **compounds** — each visit adds another layer to a living model of your body.

---

## Roadmap

The path from prototype to a billion scans a month:

| When | Milestone |
|---|---|
| Next 12 months | Refine algorithms + hardware daily; research trials; move toward Gen2 hardware; build out the first "research spa" |
| End of 2027 | **Midjourney Spa** opens in San Francisco; real-world operation at scale begins |
| 2028 | Scale to more cities; **Gen3** scanner with fully custom silicon — night-and-day image quality and scan times |
| ~2031 | Fleet of **~50,000 scanners**, **~1 billion scans/month** |

On **regulation**: every diagnostic capability normally needs FDA approval, so Midjourney starts by giving you **detailed body-composition maps** and submits regular test results to the FDA to unlock increased capabilities over time.

## A New Kind of Research Lab

Midjourney has **no investors**. It's a **community-backed research lab** — funded by everyday people — building a new community around this project: a Discord for Spa & Medical, a spa waitlist, and clinical-trial volunteering.

The closing note of the announcement is the brand's north star: ***"we are all Midjourney."*** The product voice that follows from it is hopeful, plain-spoken, and human — never clinical-portal jargon.

---

## What's Next (Not Built Yet)

These are natural extensions aligned with the Medical vision, not commitments:

- [ ] Real scan ingestion from the imaging pipeline
- [ ] User accounts, auth, and scan history sync
- [ ] Post-scan **"Wrapped"** reveal flow (`OrganScanResult` model exists, UI partial)
- [ ] Push notifications when a new scan is ready
- [ ] **Spa surfaces:** booking, waitlist, and visit scheduling (scan-as-side-effect framing)
- [ ] **Community surfaces:** Discord link, clinical-trial sign-up, "we are all Midjourney" moment
- [ ] Sharing / export for clinician review
- [ ] Expanded metric catalog as the scanner's capabilities grow
- [ ] Population-scale cohort baselines (the billion-scans/month data flywheel)

---

## References

- [Midjourney Medical — announcement & sign-up](https://midjourney.com/medical)
- Discord community for Spa & Medical updates
- First flagship: **Midjourney Spa**, San Francisco, **end of 2027**

---

## Running the Prototype

Open `MidjourneyMedical.xcodeproj` in Xcode and run on the iOS Simulator.

Environment variables (for development / snapshots):

| Variable | Effect |
|---|---|
| `SKIP_LOADING=1` | Jump straight to the tab bar |
| `START_TAB=timeline` | Open on a specific tab (`body`, `compare`, `insights`, `baseline`) |
