# Simulator end-to-end pass

Full run of the `simulator-e2e` task against the `fenix7`/`fenix7s`/`fenix7x`
builds, SDK 9.2.0 (per `app/DEVELOPMENT.md`).

## Environment constraint (same as every prior task in this repo)

This environment has neither macOS Screen Recording nor Accessibility
permission for the process driving the simulator: `screencapture` fails with
"could not create image from display", and `osascript`'s System Events
errors with "not allowed assistive access" (confirmed empirically again for
this task). There is also no CLI-driven input-simulation API in the SDK —
checked `monkeydo --help` (only loads a `.prg`/runs `(:test)` suites, no
touch/button injection flag), `monkeym` (permission-denied binary, not a
scripting entry point), and `era` (the store/publishing tool, unrelated).
So, as in every earlier task's `DEVELOPMENT.md` entry, a live click-through
driving actual touch/button events and screenshotting the result was not
possible here.

What *was* possible, and is the basis for the results below:

- Building and launching the real (non-test) app in the running simulator
  for all three device profiles, and diffing `CIQ_LOG.YML` (the simulator's
  crash log) before/after each launch to confirm no crash.
- Running the full `(:test)` suite (`monkeydo BabyDaybookTest.prg fenix7 -t`).
- Rigorously tracing every code path named in the task by hand against the
  actual source, as a careful reader simulating each user action step by
  step — the same standard of review a code reviewer would apply, checking
  every branch against the spec in `PLAN.md`.
- Inspecting the simulator's virtual device filesystem directly
  (`$TMPDIR/com.garmin.connectiq/GARMIN/...`) for the `.SET` settings file.

## Baseline

- `monkeyc -d fenix7|fenix7s|fenix7x -f monkey.jungle -y ../keys/developer_key.der`:
  **BUILD SUCCESSFUL** for all three device profiles.
- Type-check level 2 ("Informative", `-l 2`): **BUILD SUCCESSFUL** — no
  `(:background)`/`(:glance)` scope leaks.
- `monkeydo bin/BabyDaybookTest.prg fenix7 -t`: **94/94 PASS** (93 pre-
  existing + 1 new regression test added by this pass, see below).
- Launched the built `.prg` in the running simulator for `fenix7`, `fenix7s`,
  and `fenix7x` in turn; `CIQ_LOG.YML`'s content/hash was unchanged after
  each launch — no new crash entry. (The log already contained two stale
  entries from earlier development sessions, both timestamped before this
  session's first build; neither recurred.)

## Results by area

| Area | Result | Notes |
|---|---|---|
| Home (zones/highlight/badge) | **Code-verified, pass** | `HomeViewTest.mc` covers zone tiling at 240/260/280px, boundary hit-testing, highlight-from-`Store.lastAction`, and wrap-around. Traced `onTap`/`onSelect`/`onNextPage`/`onPreviousPage` by hand against `zoneAt()`/`moveHighlight()` — thin, correct wrappers. |
| Wet/Dirty instant record | **Code-verified, pass** | `RecordController.record()` enqueues before any network I/O, stamps one `nowMillis` shared by the queue item, `Store.lastEventMillis`, and `SuccessView`'s displayed time. `SuccessView.isSynced()` correctly tracks the item leaving the queue for the "Synced"/"Queued" line. |
| Bottle confirm | **Code-verified, pass** | Prefill (`lastBottleMl` else `defaultBottleMl`), stepping/clamping, below-min "— ml", BACK popping without calling `recordBottle`, and `setLastBottleMl` only firing on a non-null confirmed amount all match `BottleConfirmViewTest.mc` and a direct read of `BottleConfirmDelegate.confirm()`/`onBack()`. |
| Auth (expired token / garbage refresh token) | **Code-verified, pass** | Traced `SyncQueue.flush() -> TokenClient.getIdToken() -> onRefreshResponse()`: a near-expiry cached token refreshes once and the retried commit proceeds; a rejected refresh (400/401) reaches `AUTH_INVALID -> pauseForToken()`, which sets `Store.queueStatus.needsToken` — `HomeView.drawSyncStatus()` reads exactly that flag for its "check token" state. |
| Offline queue (5+ events, oldest-first, idempotent ids) | **Code-verified, pass; 2 bugs fixed** | `enqueue()`'s id (`"<epoch-ms>-<counter>"`) is stamped once and reused verbatim by `FirestoreClient.buildRequestBody()` on every retry — the Firestore document name never changes for a given queue item. `flush()` always takes `queue[0]`; `removeItemById()` splices out exactly that index, so relative order of the rest is preserved — oldest-first drain holds across any number of items. **Bugs found in this area, see below.** |
| Background sync | **Code-verified, pass** | `BackgroundServiceDelegate`'s wall-clock budget + `flushGate` (consulted *inside* `SyncQueue.flush()`, not just between items) correctly stops a new commit from being *dispatched* once the budget is gone, closing the "killed mid-request" gap documented in `DEVELOPMENT.md`'s own follow-up note. `finish()` always calls `ComplicationsPublisher.updateAll()`, so displayed ages stay fresh across a wake even with nothing to flush. |
| Complication launch routing + glance | **Code-verified, pass** | `BabyDaybookApp.getInitialView()`'s three-way branch on `launchedFromComplication` (Wet/Dirty -> exiting `SuccessView`, Bottle -> `BottleConfirmView(exitOnConfirm=true)`, else -> `HomeView`) matches `BabyDaybookAppTest.mc`'s 4 routing cases exactly. `GlanceView` only touches `Store.mc`'s `(:glance)`-tagged accessors (confirmed no network-stack import), and selecting a glance falls through to `getInitialView()` by default platform behavior — no extra code needed or present. |
| Settings `.SET` workflow | **Live-verified, pass** | Loading the built app in the simulator (no settings-editor interaction needed for this step) created `$TMPDIR/com.garmin.connectiq/GARMIN/APPS/SETTINGS/BABYDAYBOOK.SET` — exact path and filename (`.prg` name, uppercased, `.SET` extension) `DEVELOPMENT.md` documents. Inspected the file directly: an opaque binary struct listing all 7 declared properties (`bottleMinMl`, `bottleStepMl`, `babyUid`, `bottleMaxMl`, `defaultBottleMl`, `refreshToken`, `syncIntervalMinutes`) with their `properties.xml` defaults, confirming `settings.xml`'s declared set round-trips into the `.SET` format as documented. Opening the simulator's interactive settings-editor GUI and re-saving was not possible (same Accessibility/Screen-Recording constraint above) — the doc's claim about that step is unverified live this pass, as it has been in every prior task. |
| Real Firebase network round trip (online flush success) | **Not exercised** | `properties.xml` ships with an empty `refreshToken`/`babyUid` by design (personal-sideload secret, never committed real) — there is no valid credential in this environment to drive an actual `securetoken.googleapis.com`/`firestore.googleapis.com` round trip. This has never been exercised live in any task in this repo; unchanged this pass. The request-building/response-classification logic on both ends is fully unit-tested (`TokenClientTest.mc`, `FirestoreClientTest.mc`). |

## Bugs found and fixed

1. **`SyncQueue.isQueueOverflowed()` was set but never read by any view.**
   `enqueue()` correctly caps the queue at 100 items and sets this flag when
   it drops the oldest item, but nothing displayed it — a user who filled
   the offline queue past 100 items (e.g. days of watch-only use with no
   phone nearby) would silently lose the oldest queued record with no
   on-watch indication anything was dropped.
2. **`SyncQueue.consumeLastError()` was set but never read by any view.**
   A permanently-rejected commit (Firestore 400/403) correctly drops the
   item and sets `Store.queueStatus.lastError`, but nothing ever consumed
   it — the "shown once" error this flag was designed for (per the
   `sync-queue` task's own spec) would never actually show.

   Fix (`app/source/HomeView.mc`): `onShow()` now calls
   `SyncQueue.consumeLastError()` into a new `hadLastError` instance var,
   and `drawSyncStatus()` shows one of, in priority order, "check token"
   (blocks all flushing) / "queue full" (foreground-only overflow warning)
   / "sync error" (one-shot permanent-failure banner) / the existing
   pending-count badge — each replacing the others rather than stacking.
   Covered by a new regression test,
   `HomeViewTest.testOnShowConsumesLastErrorExactlyOnce`, asserting the
   flag reads `true` once then `false` on a second `onShow()`. Full suite
   passes at 94/94 after the fix; a normal build still succeeds for all
   three device profiles and at type-check level 2.

No other defects were found in this pass — every other traced path already
matched its `PLAN.md` spec and existing test coverage exactly.

## Recommended before closing this task fully

A real click-through — tapping each zone/stepper/confirm button with touch
and buttons, toggling the simulator's network on/off around a Wet/Dirty
record, watching the badge/"check token"/"queue full"/"sync error" states
render, and opening the simulator's settings editor to confirm a saved edit
round-trips to the watch — needs either Screen Recording + Accessibility
permission granted to whatever process drives the simulator, or a physical
device pass (tracked separately in `docs/device-testing.md`, the
`device-test-checklist` task).

## Final re-check before closing out

Re-ran the automated portion of this pass as a final gate before considering
the project done:

- `monkeyc -d fenix7 -f monkey.jungle -o bin/BabyDaybookTest.prg -y
  ../keys/developer_key.der -t`: **BUILD SUCCESSFUL**.
- `monkeydo bin/BabyDaybookTest.prg fenix7 -t`: **94/94 PASS**, no
  failures/errors.
- Normal builds for all three device profiles
  (`fenix7`/`fenix7s`/`fenix7x`): **BUILD SUCCESSFUL** for each.
- Type-check level 2 ("Informative", `-l 2`): **BUILD SUCCESSFUL** — still no
  `(:background)`/`(:glance)` scope leak.
- Smoke test: launched each of the three built `.prg`s in the running
  `connectiq` simulator in turn; `CIQ_LOG.YML`'s hash was identical before
  and after all three launches — no new crash entry from any profile.

No regressions found. The live touch/button click-through and the settings-
editor GUI round-trip remain the only unverified items, for the same
Screen Recording/Accessibility permission constraint documented throughout
this file and `app/DEVELOPMENT.md`.
