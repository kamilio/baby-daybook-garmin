# Development setup

Connect IQ toolchain for building and testing the Baby Daybook watch app
(sideloaded personal app, Fenix 7 family). macOS host.

## SDK

Installed via the Connect IQ SDK Manager (`garmin.connectiq.sdkmanager`),
not Homebrew:

- SDK Manager app data: `~/Library/Application Support/Garmin/ConnectIQ/`
- Active SDK: `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2/`
  (`bin/version.txt`; satisfies the >= 7.4.3 requirement for sideloads on
  current Fenix firmware)
- Device profiles: `~/Library/Application Support/Garmin/ConnectIQ/Devices/`
  — includes `fenix7`, `fenix7s`, `fenix7x`, and the Pro/no-wifi variants
  (`fenix7pro`, `fenix7spro`, `fenix7xpro`, `fenix7pronowifi`,
  `fenix7xpronowifi`)

`monkeyc` and the simulator (`connectiq`, `monkeydo`) are on `PATH` via
`~/.zshrc`:

```sh
export PATH="/Users/kjopek/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2/bin:$PATH"
```

This points at one specific SDK version; when the SDK Manager installs a
newer version, update the path (or symlink a stable `Sdks/current` name)
and re-source `~/.zshrc`. Verify with:

```sh
monkeyc --version
```

## Signing key

Every sideloaded `.prg` must be signed with a self-generated key — no
Garmin developer account needed. Key pair lives in `../keys/` (gitignored,
never commit it):

```sh
openssl genrsa -out keys/developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -nocrypt \
  -in keys/developer_key.pem -out keys/developer_key.der
```

Only `developer_key.der` is used for builds; `developer_key.pem` is the
source key material, kept for regenerating the DER if needed.

## Properties (secrets and tuning)

`resources/properties.xml` declares the app's build-time properties;
`resources/settings.xml` describes their editor UI (used by the simulator's
settings dialog and by Garmin Express/Connect for *published* apps). This
app is a personal sideload, so Garmin Connect never gets a chance to edit
these settings — whatever is baked into `properties.xml` at build time is
what the watch starts with. Runtime code (`source/Config.mc`) reads
`Application.Properties`, but for `refreshToken` prefers a value cached in
`Application.Storage` under the `authCache` key once one exists, since
Firebase rotates that token after first use and the rotated value must win
over the baked-in default.

Properties:

| id                    | type   | default | notes |
|-----------------------|--------|---------|-------|
| `refreshToken`        | string | `""`    | Firebase refresh token (~200 chars). Secret — masked as a password field in the simulator settings editor. |
| `babyUid`              | string | `""`    | Baby UID from `baby-daybook babies list`. |
| `syncIntervalMinutes` | number | `15`    | Background sync interval; runtime floor is 5 (`Config.SYNC_INTERVAL_MINUTES_FLOOR`), the Connect IQ temporal-event minimum. |
| `defaultBottleMl`     | number | `120`   | Prefill amount when no bottle has been recorded yet. |
| `bottleStepMl`        | number | `10`    | −/+ stepper increment on the bottle confirm screen. |
| `bottleMinMl`         | number | `30`    | Stepping at/below this shows "— ml" (record without an amount). |
| `bottleMaxMl`         | number | `300`   | Upper stepper bound. |

### Setting real values before building

Edit the defaults directly in `resources/properties.xml` before running
`monkeyc`, e.g.:

```xml
<property id="refreshToken">AMf-vBx...</property>
<property id="babyUid">abc123</property>
```

Get both values via the JS SDK (`baby-daybook-sdk`): `baby-daybook login
apple` provisions `~/.config/baby-daybook/auth.json`, then
`baby-daybook babies list --output json` prints the baby UID. Never commit
real values — `properties.xml` holds a personal secret once filled in;
keep it out of diffs you share, and restore it to the empty defaults
before pushing if this repo is ever made non-private.

**Gotcha confirmed by testing: rebuilding does not reset already-persisted
properties.** Once this app (identified by its manifest UUID) has been
installed and run anywhere — the simulator or a real watch — Connect IQ
persists its property values to that device's own storage. A later
`monkeyc` build with new `properties.xml` defaults only takes effect on a
device/simulator that has never run this UUID before; on one that already
has it installed, the *old* persisted values keep winning even after
reinstalling the new `.prg`, because installing over an existing app updates
the binary but not its already-persisted settings. Concretely: if you first
build and run the placeholder (empty-string) app in the simulator while
scaffolding, then later fill in the real `refreshToken`/`babyUid` and
rebuild, the simulator will still report the *empty* placeholders until you
clear the persisted settings — confirmed by rebuilding
`Config.getSyncIntervalMinutes()`'s backing property with a new default and
observing `Properties.getValue` still return the old one until the settings
file was removed.

Fix: before (re)installing a build with corrected property defaults onto a
device/simulator that has run this app before, clear its persisted
settings first:
- **Simulator**: delete the app's `.SET` file under
  `$TMPDIR/com.garmin.connectiq/GARMIN/APPS/SETTINGS/` (or use the
  simulator menu's per-app "reset settings"/"remove app data" action if
  present) before the next `monkeydo`.
- **Real watch**: delete `/GARMIN/APPS/SETTINGS/<name>.SET` over USB/MTP (or
  fully remove and reinstall the app) before copying the corrected `.prg`.

This matters most for `refreshToken`/`babyUid`, since they're exactly the
properties this project bakes in once and expects to be correct — a typo
fixed only in `properties.xml` and rebuilt will *not* reach the watch until
the stale persisted settings are cleared.

### No-rebuild alternative: `.SET` file swap

Because the refresh token expires or needs rotating occasionally, and
because re-running `monkeyc` for a one-value change is slow, Connect IQ
lets you change property values without rebuilding the `.prg`, by editing
a `.SET` file and copying it to the watch:

1. Launch the simulator (`connectiq &`) and load the built app
   (`monkeydo BabyDaybook.prg fenix7`). Loading the app alone creates a
   `.SET` file with all properties at their `properties.xml` defaults —
   confirmed on macOS at
   `$TMPDIR/com.garmin.connectiq/GARMIN/APPS/SETTINGS/BABYDAYBOOK.SET`
   (the simulator's virtual device filesystem mirrors the real
   `/GARMIN/...` layout under `$TMPDIR/com.garmin.connectiq/GARMIN/`; the
   filename is the `.prg` name, uppercased, with a `.SET` extension).
2. Open the simulator's settings editor for the running app (simulator
   menu → **Settings**) and edit the values there — it uses the same
   `resources/settings.xml` UI (titles, types, min/max, `maxLength`) — then
   save; this rewrites the same `.SET` file in place.
3. Copy that `.SET` file to `/GARMIN/APPS/SETTINGS/` on the watch over
   USB/MTP, keeping the same filename as the installed `.prg` (e.g.
   `BabyDaybook.SET` next to wherever `BabyDaybook.prg` was installed).
   The watch picks it up on the next app launch — no reinstall needed.

This only changes property values already declared in `settings.xml`; it
cannot add new properties or change code. The `.SET` format is an
undocumented binary struct dump — treat it as opaque and always produce it
via the simulator's editor, not by hand.

## Build

From `app/`, once `monkey.jungle` exists:

```sh
monkeyc -d <deviceId> -f monkey.jungle -o BabyDaybook.prg -y ../keys/developer_key.der
```

`<deviceId>` is one of `fenix7`, `fenix7s`, `fenix7x` (or the Pro variants).
Build a separate `.prg` per device — Connect IQ device binaries are not
interchangeable across profiles.

## Simulator

Launch the simulator, then run a build in it:

```sh
connectiq &                 # starts the device simulator UI
monkeydo BabyDaybook.prg <deviceId>   # loads and runs the built .prg on the running simulator
```

`connectiq` must be running before `monkeydo` will attach.

### Glance launch mode

The simulator defaults complication taps (`Complications.exitTo`) to
glance-mode launch. For testing complication-driven launches, set the
simulator's **Glance Launch Mode** to **Launch in Normal Mode**
(simulator menu, per-app or global setting) so the app opens normally
instead of into its glance.

### Testing published complications

This app publishes three `Toybox.Complications` complications (Bottle=0,
Wet=1, Dirty=2 — `resources/complications.xml`, updated by
`source/ComplicationsPublisher.mc`). **Known platform limit: only CIQ watch
faces that themselves subscribe to complications can display them — Garmin's
stock/pre-installed watch faces cannot show a third-party app's CIQ
complications.** To actually see the published Bottle/Wet/Dirty values
rendered on a watch face (in the simulator or on the real device), install a
CIQ watch face that maps arbitrary/CIQ complications (a "configurable"
watch face with a free complication slot; the SDK's own `ConfigurableWatchFace`
sample is one example of the mechanism, though it doesn't ship a UI for
picking a third-party app's complication by hand — a store face built for
that is what you actually want) and assign one of its complication slots to
this app's Bottle/Wet/Dirty complication.

Without such a face, the simulator's own **Complication Viewer** (in the
simulator's menu bar, next to the navigation/data-field inspectors) lists
every complication currently published by the running app together with its
live `value`/`shortLabel` — use it to confirm `ComplicationsPublisher` is
publishing the right values (e.g. "45m", "2h", "—") without needing a
subscribing face at all. It's the fastest way to verify a publish call
actually landed after a record, an app start, or a fired temporal event.

## Unit tests

Connect IQ's native test framework compiles `(:test)`-annotated functions
(e.g. `source/ConfigTest.mc`) only when built with `-t`; a normal build
ignores them:

```sh
monkeyc -d fenix7 -f monkey.jungle -o bin/BabyDaybookTest.prg -y ../keys/developer_key.der -t
connectiq &                                            # if not already running
monkeydo bin/BabyDaybookTest.prg fenix7 -t              # runs every (:test) function
monkeydo bin/BabyDaybookTest.prg fenix7 -t Module.testName   # runs just one
```

Tests share the simulator's persisted `Storage`/`Properties` state (the same
mechanism as the "Gotcha" above), so tests that assert on `Storage` values
should `Storage.clearValues()` at the start and end of the test, and tests
that assert on baked-in `Properties` defaults are only meaningful right
after a fresh install (no stale `.SET` file for this app).

## Verification performed

Confirmed the toolchain end-to-end by building the SDK's bundled `Analog`
sample for `fenix7`, signed with `keys/developer_key.der`:

```sh
monkeyc -d fenix7 -f monkey.jungle -o Analog.prg -y ../keys/developer_key.der
```

Result: `BUILD SUCCESSFUL`.

Verified `Config.mc` against `source/ConfigTest.mc` (10 cases: refresh-token
Storage-override precedence, malformed/empty Storage values falling back to
the baked-in property, the sync-interval floor clamp at boundary values, and
that bottle/babyUid getters never return `null`). All 10 pass via
`monkeydo BabyDaybookTest.prg fenix7 -t`. Also confirmed a normal
(non-`-t`) build still succeeds with `ConfigTest.mc` present in
`source/`, i.e. test code doesn't leak into release builds.

Verified `Store.mc` against `source/StoreTest.mc` (16 cases covering every
accessor: safe defaults on empty Storage, malformed/wrong-type stored
values falling back to those defaults, and get/set round-trips — including
epoch-millisecond values above the 32-bit `Number` range via `Long`
literals for `authCache.expiresAtMillis` and `lastEventMillis`). All 16
pass via `monkeydo BabyDaybookTest.prg fenix7 -t` (26/26 total across
`ConfigTest` + `StoreTest`). Confirmed a normal build still succeeds with
`Store.mc`/`StoreTest.mc` present.

Verified `TokenClient.mc` against `source/TokenClientTest.mc` (7 cases:
cache-hit short-circuiting, `invalidateIdToken()` preserving the refresh
token/user id while zeroing expiry, `getUserId()` default and stored-value
paths, `refreshInFlight` not sticking on the no-refresh-token branch across
repeated `getIdToken()` calls, and `expires_in` parsing for string/number/
malformed input). The refresh HTTP round trip itself
(`Communications.makeWebRequest`) isn't covered by `(:test)` — it needs a
live network call — so it's exercised manually in the simulator instead. All
7 pass via `monkeydo BabyDaybookTest.prg fenix7 -t` (34/34 total across
`ConfigTest` + `StoreTest` + `TokenClientTest`). Confirmed a normal build
still succeeds with `TokenClient.mc`/`TokenClientTest.mc` present, and that
`(:background)` annotations hold (no UI imports pulled into the module).

Verified `FirestoreClient.mc` against `source/FirestoreClientTest.mc` (9
cases: `documents:commit` request-body field encoding for both event types
per `docs/wire-format.md` -- `volume` as `doubleValue`, `pee`/`poo` as
`integerValue` `"0"`/`"1"` (not `booleanValue`, despite them being boolean-
shaped) -- the document `name` path and `svt` `REQUEST_TIME`
`updateTransforms` entry, and response status-code classification across
the 2xx/401/400/403/other boundaries). All 9 pass via `monkeydo
BabyDaybookTest.prg fenix7 -t` (43/43 total across `ConfigTest` +
`StoreTest` + `TokenClientTest` + `FirestoreClientTest`). The commit HTTP
round trip itself isn't covered by `(:test)` -- it needs a live network
call -- so it will be exercised manually once `SyncQueue.mc` wires it up.
Confirmed a normal build still succeeds with
`FirestoreClient.mc`/`FirestoreClientTest.mc` present, and that
`(:background)` annotations hold (no UI imports pulled into the module).

Verified `SyncQueue.mc` against `source/SyncQueueTest.mc` (11 cases:
`enqueue()` stamping `id`/`startMillis`/`attempts` and appending to the
Storage-backed queue, the 100-item cap dropping the oldest entry and
setting the overflow flag, `flush()` no-op'ing while `Store.queueStatus`
reports paused, the bottle/wet/dirty action mapping used for
`lastEventMillis`, the shared by-id queue helpers
(`findItemById`/`removeItemById`/`incrementAttemptsById`), and the
`lastError`/`needsToken` flags each round-tripping through `Store.mc`).
With Storage cleared and no refresh token configured, `TokenClient`'s
refresh path takes its synchronous no-web-request branch (see
`TokenClientTest`), so `enqueue()` -> `flush()` never reaches the network in
these tests -- it always settles into the paused-for-token state, which is
what most of the assertions check. The commit/token HTTP round trips
themselves aren't covered by `(:test)`; exercising the full online flush,
the one-retry-after-401 path, and the background-shared-queue race is left
to the simulator once `RecordController`/background sync wire this module
up. All 11 pass via `monkeydo BabyDaybookTest.prg fenix7 -t` (56/56 total
across `ConfigTest` + `StoreTest` + `TokenClientTest` +
`FirestoreClientTest` + `SyncQueueTest`, the last 2 of which are new
`Store.queueStatus` cases added alongside `SyncQueue.mc`). Confirmed a
normal build still succeeds with `SyncQueue.mc`/`SyncQueueTest.mc` present,
`(:background)` annotations hold, and that `TokenClient.mc`/
`FirestoreClient.mc` still build and pass after their `nowEpochMillis()`
duplication was extracted into a new shared `TimeUtil.mc` module.

Verified `HomeView.mc`/`HomeDelegate.mc` against `source/HomeViewTest.mc` (6
cases: the three tap-zone bounds tile the full display height with no gap
or overlap at all three round profiles (240/260/280 px) and the Wet zone is
always the widest band; `zoneAt()` boundary pixels resolve to the correct
neighboring zone with no off-by-one; the zone<->action string mapping
round-trips both ways and defaults to Wet for `null`/unrecognized actions;
the initial highlight ring reflects `Store.lastAction` (Bottle/Dirty/none ->
Wet default); and `moveHighlight()` wraps correctly in both directions).
All 6 pass via `monkeydo BabyDaybookTest.prg fenix7 -t` (62/62 total).
Confirmed a normal build succeeds for all three real device IDs
(`fenix7`, `fenix7s`, `fenix7x`), and that removing the now-dead
`BabyDaybookView`/`BabyDaybookDelegate` scaffold placeholders (superseded by
`HomeView`/`HomeDelegate` as the app's initial view) doesn't break the build.

Live touch/button interaction in the simulator window (tapping each zone,
Up/Down/START/BACK) was **not** exercised end-to-end in this environment:
the sandboxed shell driving the build has neither macOS Screen Recording
nor Accessibility permission, so `screencapture` can't image the simulator
window and synthetic input tools (`cliclick`) can't deliver clicks/keys to
it (both fail with permission errors, confirmed empirically). What *was*
confirmed live: the app builds and launches in the `fenix7` simulator via
`monkeydo` without crashing. The tap hit-testing, zone geometry, and
highlight-navigation logic that the touch/button paths call into is fully
covered by `HomeViewTest.mc` above; `onTap`/`onNextPage`/`onPreviousPage`/
`onSelect`/`onBack` themselves are thin wrappers over that logic (verified
by code review against the `WatchUi.BehaviorDelegate`/`ClickEvent` API).
A real click-through pass (or a physical-device pass) is still recommended
before treating this task's `test`/`commit` steps as fully closed.

Verified `RecordController.mc`/`SuccessView.mc` against
`source/RecordControllerTest.mc` + `source/SuccessViewTest.mc` (4 cases: the
`recordDiaper`/`recordBottle` action-label formatting -- "Wet diaper" /
"Dirty diaper" / "Bottle 120 ml" / "Bottle" -- and `SuccessView`'s 24h ->
12h/AM-PM clock formatting and queue-membership `isSynced()` check). `record()`
(shared by both entry points) enqueues via `SyncQueue.enqueue()`, which now
returns the assigned queue id and keeps a caller-supplied `startMillis`
instead of re-deriving its own, so the enqueued event, `Store.lastEventMillis`,
and the time `SuccessView` displays are guaranteed to agree; this update to
`SyncQueue.enqueue()`'s signature doesn't break any existing
`SyncQueueTest.mc` case (none pre-supply `startMillis`). All 4 new cases
pass, and the full suite (66/66 across all `*Test.mc` modules) still passes,
via `monkeydo BabyDaybookTest.prg fenix7 -t`. Confirmed a normal build still
succeeds with the two new files present, and that the app launches in the
`fenix7` simulator via `monkeydo` without crashing.

`record()`/`recordDiaper()`/`recordBottle()` themselves push `SuccessView`
as their last step, and `SuccessView.onShow()` starts a live 2 s
`Timer.Timer` and, on dismiss, calls `WatchUi.popView()` or `System.exit()`
-- none of that is exercised by `(:test)`, consistent with this project's
existing pattern of not unit-testing view-push/input-handler code (see the
`HomeView`/`HomeDelegate` note above). The same environment constraint
applies here: no Screen Recording/Accessibility permission, so the actual
tap-to-record flow, the checkmark/label/status-line rendering, the
"Synced" vs "Queued" transition, and the offline case (simulator network
off -> "Queued" for the full 2 s) were **not** driven live in this
environment. What *was* confirmed: the pure logic above (label formatting,
clock formatting, queue-membership check), that `SyncQueue.enqueue()`'s
new caller-supplied-`startMillis` behavior doesn't regress the existing
offline/paused-for-token path (`SyncQueueTest.mc` still passes unchanged),
and that `HomeDelegate` already wires `Wet`/`Dirty` taps to
`RecordController.recordDiaper()` (from the earlier `home-view` task) with
no further changes needed. A real click-through pass -- including toggling
the simulator's network off before tapping Wet/Dirty to confirm "Queued"
persists and then back on to confirm it flips to "Synced" -- is still
recommended before treating this task's `test`/`commit` steps as fully
closed.

Verified `BottleConfirmView.mc`/`BottleConfirmDelegate.mc` against
`source/BottleConfirmViewTest.mc` (6 cases: prefill from `Store.lastBottleMl`
else `Config.defaultBottleMl`; `increment()` clamping at `bottleMaxMl`;
`decrement()` at `bottleMinMl` parking at "no amount" (`amountMl == null`,
displayed as "— ml") and staying there on repeated decrements;
`increment()` from "no amount" jumping back to `bottleMinMl`; `amountText()`
formatting; and the minus/plus/confirm zone hit-testing agreeing with
`computeZoneBounds()`). All 6 pass via `monkeydo BabyDaybookTest.prg fenix7
-t` (72/72 total). `HomeDelegate.activate()`'s existing
`new BottleConfirmView()` / `new BottleConfirmDelegate()` push call needed a
one-line update (the delegate now takes the view instance, matching
`HomeDelegate`'s own pattern of hit-testing against the exact view that was
last drawn) -- confirmed it still compiles and the Bottle zone still pushes
the confirm view.

The confirm handler pops `BottleConfirmView` before calling
`RecordController.recordBottle()` (rather than pushing `SuccessView` on top
of it), so `SuccessView`'s auto-dismiss pop lands back on `HomeView` --
matching the diaper instant-record flow -- instead of back on the confirm
screen. `Store.setLastBottleMl()` is only called when the confirmed amount
is non-null, per spec (a "no amount" confirm never overwrites the last
prefill).

Holding −/+ auto-repeats via `onHold`/`onRelease` (a 180 ms `Timer.Timer`
started on hold, stopped on release) rather than firing on every physical
touch-down event, since `WatchUi.InputDelegate` only exposes a single
one-shot `onHold` per press-and-hold gesture (confirmed against the SDK's
bundled `Input` sample, `samples/Input/source/InputDelegate.mc`) -- no
continuous key-repeat event exists for touch. `onTap` (for discrete taps),
`onHold`/`onRelease` (for held taps), `onNextPage`/`onPreviousPage` (Up/Down,
single step), `onSelect` (START, confirms), and `onBack` (BACK, cancels via
plain `popView`, nothing saved) are thin wrappers over `BottleConfirmView`'s
tested stepper/hit-test logic, following this project's established pattern
of not unit-testing view-push/input-handler code directly.

Same environment constraint as the two tasks above: no Screen
Recording/Accessibility permission, so the live touch/button walkthrough
(tapping −/+, holding −/+ to confirm the repeat feels responsive, tapping
CONFIRM, Up/Down/START/BACK, and the below-minimum "— ml" no-amount record)
was **not** driven live in this environment. What *was* confirmed: a normal
build succeeds with `BottleConfirmView.mc` present, and `monkeydo
BabyDaybook.prg fenix7` launches and runs without crashing. A real
click-through pass -- both input modes, per the task's own instruction --
is still recommended before treating this task's `test`/`commit` steps as
fully closed.

Added `source/BackgroundService.mc` (`BackgroundServiceDelegate`, a
`System.ServiceDelegate`) plus the registration wiring in
`BabyDaybookApp.mc` (`getServiceDelegate()`, and `onStart()` calling
`registerBackgroundSync()`). `Config.mc` is now fully `(:background)`-safe
(every function annotated, matching `Store.mc`'s existing pattern), which
was the one module in the background dependency chain
(`Store`/`Config`/`TokenClient`/`FirestoreClient`/`SyncQueue`) not yet
annotated.

`SyncQueue.flush()` already self-chains from item to item via
`advance()` and stops at the first failure (paused-for-token or
retryable), so `BackgroundServiceDelegate.onTemporalEvent()` doesn't need
its own multi-item drain loop -- it just calls `SyncQueue.flush()` once and
waits for the chain to settle. Detecting "settled" (so `Background.exit()`
fires as soon as there's genuinely nothing left in flight, rather than
holding the process open for the full budget) needed one small addition to
`SyncQueue.mc`: a `isFlushing()` accessor (`pendingId != null`), and
reordering `flush(); notifyChanged();` (was `notifyChanged(); flush();`) in
`enqueue()` and `advance()` so `isFlushing()` is accurate by the time any
`onChanged` callback observes it -- otherwise a callback firing mid-`advance()`
would see the momentary `pendingId == null` between finishing one item and
starting the next, and could exit one item early. The reorder doesn't
change observable behavior for the existing `onChanged` consumers
(`HomeView`/`SuccessView` just call `WatchUi.requestUpdate()`, order-
independent), and the full existing `SyncQueueTest.mc` suite still passes
unchanged.

Registration tracks its own "last registered interval" in a new
`Store.registeredSyncIntervalMinutes` key rather than trying to compare
against `Background.getTemporalEventRegisteredTime()` directly --
that API only returns the next scheduled `Moment`, not the interval that
produced it, so it can't be diffed against `Config.getSyncIntervalMinutes()`
on its own. `registerBackgroundSync()` treats
`getTemporalEventRegisteredTime() == null` (nothing registered with the
platform at all -- first run, or a stale Store value surviving a
registration that was separately cleared) as always requiring
registration, and otherwise re-registers only when the configured interval
differs from what's stored. The decision itself is split into a pure
`shouldRegisterSyncInterval(minutes, registeredMinutes, hasRegistration)`
method, tested directly (`BabyDaybookAppTest.mc`, 4 cases) without touching
the real `Background` API.

Verified: a normal (non-`-t`) build succeeds with `BackgroundService.mc`
present and the background dependency chain's new `(:background)`
annotations in place, and `monkeydo BabyDaybook.prg fenix7` still launches.
Full unit suite passes at 79/79 (`monkeydo BabyDaybookTest.prg fenix7 -t`),
including the 4 new `BabyDaybookAppTest` cases and 1 new
`SyncQueueTest.testIsFlushingFalseWhenNoCommitInFlight` case.

The live end-to-end path -- tapping a diaper zone with the simulator's
network toggled off so the record queues instead of syncing, then using
the simulator's **Simulation → Background Events → Temporal Event** menu
item (the only way to force a temporal event; confirmed against the SDK's
own `doc/docs/Core_Topics/Backgrounding.html`, which documents no CLI
equivalent) to fire `onTemporalEvent()` and confirm the queue drains and
`Store.lastEventMillis` updates -- was **not** driven live in this
environment, same Screen Recording/Accessibility constraint as the tasks
above (confirmed empirically: `osascript`/System Events GUI scripting
against the simulator process fails with "not allowed assistive access").
A real click-through pass covering that offline-enqueue-then-fire sequence
is still recommended before treating this task's `test`/`commit` steps as
fully closed.

### Follow-up: budget check ran one item too late

Auditing the drain chain by hand (since the live simulator click-through
above is blocked) turned up a real bug in the wall-clock budget: it never
actually stopped the flush chain from *starting* a new item once the
27 s budget was gone -- only from continuing to hold the process open
afterwards.

`TokenClient.getIdToken()` answers synchronously whenever the cached ID
token is still valid (`TokenClient.mc`, the `cachedIdToken.length() > 0 &&
... > TOKEN_EXPIRY_SKEW_MILLIS` branch) -- the common case for a
multi-item background drain, since one ID token covers an hour. That means
`SyncQueue.advance() -> flush() -> requestToken() -> onToken()` (all
synchronous) reaches `FirestoreClient.commitEvent()` -- which *does* start
a real, asynchronous `makeWebRequest` -- all within the same call stack as
the *previous* item finishing. Only after `flush()` returns does
`advance()` call `notifyChanged()`, which is what drives
`BackgroundServiceDelegate.checkSettled()`'s budget check. So by the time
that check ran, the next item's commit had already been dispatched: an
over-budget result didn't stop that request from starting, it just made
`finish()` call `Background.exit()` while it was still in flight --
abandoning a request that had just gone out over the radio, exactly the
"killed mid-request" outcome the budget was meant to avoid, except
self-inflicted instead of OS-inflicted.

Fix: added `SyncQueue.setFlushGate(gate as Method?)` -- an optional
predicate consulted at the top of `flush()`, before it sets `pendingId`
or calls `requestToken()`. `BackgroundServiceDelegate.onTemporalEvent()`
sets it to `hasBudget()` (`elapsedMillis() < WALL_CLOCK_BUDGET_MILLIS`)
and clears it in `finish()`; the foreground app never sets it, so
`flush()` behaves exactly as before there (`flushGate == null` always
dispatches). With the gate in place, once the budget is gone `flush()`
returns without touching `TokenClient`/`FirestoreClient` at all, so
`isFlushing()` is already `false` by the time `checkSettled()` runs and
`finish()` only ever happens between items, never mid-request. Covered by
`SyncQueueTest.testFlushGateBlocksDispatchOfNewItem`, which sets a
gate that always denies and asserts the queued item is untouched and
`needsToken` never flips.

Verified after the fix: full unit suite passes at 80/80 (`monkeydo
BabyDaybookTest.prg fenix7 -t`), a normal build still succeeds
(`monkeyc ... -o bin/BabyDaybook.prg`), and a build at type-check level 2
(`-l 2`, "Informative" -- the level the SDK's Backgrounding doc says is
needed to catch a `(:background)`-scope leak) is also clean, confirming
the background dependency chain (`Store`/`Config`/`TokenClient`/
`FirestoreClient`/`SyncQueue`/`BackgroundService`/`BabyDaybookApp`) still
has no accidental UI reference. (Level 3, "Strict", reports a long list of
pre-existing untyped/`PolyType` findings across the whole codebase,
unrelated to this task -- the project isn't built at that level normally.)
The live GUI click-through in the simulator remains blocked in this
environment for the same accessibility-permission reason noted above;
still recommended before closing this task's `test`/`commit` steps.

Added `source/ComplicationsPublisher.mc` (`(:background)`-safe, no UI
imports) publishing the app's three complications --
`resources/complications.xml` defines ids 0 (Bottle) / 1 (Wet) / 2 (Dirty),
each `access="public"` with an svg icon (`resources/*_complication_icon.svg`,
new `Drawables.*ComplicationIcon` entries) and a static `longLabel`
("Last bottle" etc., only settable in the resource, not at runtime).
`ComplicationsPublisher.updateAll()` reads `Store.getAllLastEventMillis()`
and calls `Complications.updateComplication(id, {:value, :shortLabel})` with
a compact age string from the new pure `formatAge()` helper ("Nm" under an
hour, "Nh" under a day, "Nd" beyond that, "—" when never recorded) --
`:unit` is intentionally omitted rather than passed as `null`, since the
`Complications.Data` typedef's `:unit` field type (`Unit or String`) doesn't
accept `Null` and the type checker rejects it. `updateAll()` is called from
`RecordController.record()` (after every successful record), from
`BabyDaybookApp.onStart()` (covers both a real foreground app start and the
`onStart()` background processes also run before their service delegate --
see the `background-sync` note above), and from
`BackgroundServiceDelegate.finish()` (end of every temporal wake, so the
published age keeps advancing with wall-clock time even while the app stays
closed and no record/flush actually changed anything).

Verified `ComplicationsPublisher.formatAge()` against
`source/ComplicationsPublisherTest.mc` (5 cases: never-recorded -> "—",
minute formatting up to the 59m/60m boundary, hour formatting up to the
23h/24h boundary, day formatting, and clamping a future `lastEventMillis`
-- clock skew -- to "0m" instead of going negative). `updateOne()`/
`updateAll()` themselves call `Complications.updateComplication()`, which
needs a real subscriber or the simulator's Complication Viewer to observe;
not exercised by `(:test)`, consistent with this project's pattern of not
unit-testing calls into live platform APIs. All 5 new cases pass, and the
full suite (85/85 across every `*Test.mc` module) still passes, via
`monkeydo BabyDaybookTest.prg fenix7 -t`. Confirmed a normal build succeeds
for all three real device IDs (`fenix7`, `fenix7s`, `fenix7x`), that a
type-check level 2 ("Informative") build is clean (no `(:background)`-scope
leak from the new module), and that `monkeydo BabyDaybook.prg fenix7`
launches without a new `CIQ_LOG.YML` crash entry.

The live verification this task calls for -- confirming the three
complications actually appear with the right icon/long label/short-label
age either in the simulator's Complication Viewer or on a subscribing test
watch face, and that the value visibly advances/refreshes after a record,
an app relaunch, and a fired temporal event -- was **not** driven live in
this environment: same missing Screen Recording/Accessibility permission
noted throughout this file, which blocks both `screencapture` and synthetic
input against the simulator window. What *was* confirmed: the pure
age-formatting logic above, that the publish call itself type-checks and
builds cleanly across every device/background configuration, and that nothing
in this change regresses the existing 80 tests. A real Complication
Viewer / subscribing-watch-face pass is still recommended before treating
this task's `test`/`commit` steps as fully closed.

Wired up complication-launch routing in `BabyDaybookApp.mc`: `onStart()`
reads `state[:launchedFromComplication]` (a `Lang.Number` -- confirmed
against the bundled SDK's `Toybox/Application/AppBase.html` docs, which
document it as "the complication index the app was launched from", present
only when a watch face called `Complications.exitTo()` for one of this
app's own published complications) into a new public instance var, and
`getInitialView()` (which the docs confirm always runs after `onStart()`)
branches on it:

- Wet/Dirty (`ComplicationsPublisher.ID_WET`/`ID_DIRTY`) -> a new
  `RecordController.recordDiaperInitialView()` records instantly and
  returns `[SuccessView, SuccessDelegate]` directly as the initial view,
  with `exitOnDismiss` set -- there's no home view to `WatchUi.pushView()`
  onto yet at `getInitialView()` time, so the checkmark screen has to *be*
  the initial view rather than be pushed onto one.
- Bottle (`ID_BOTTLE`) -> `new BottleConfirmView(true)` as the initial view.
  `BottleConfirmView`/`BottleConfirmDelegate` gained an `exitOnConfirm` flag
  (constructor param, so the existing `new BottleConfirmView()` call sites
  in `HomeDelegate`/`BottleConfirmViewTest` needed a `false` argument added):
  the normal flow still pops `BottleConfirmView` before recording (so
  `SuccessView`'s dismiss-pop lands on `HomeView`, unchanged from the
  `bottle-confirm-view` task), but the complication-launch flow can't pop
  first -- popping the app's only view exits it immediately, before
  `SuccessView` ever shows -- so `confirm()` instead pushes `SuccessView`
  (with `exitOnDismiss = true`) on top of `BottleConfirmView`, and the
  `System.exit()` on dismiss happens without any further pop. `onBack()`
  needed no change: popping the app's sole initial view already exits it,
  which is exactly "BACK exits without saving" for this path too.
- Anything else (no `:launchedFromComplication`, i.e. launcher/glance/
  hotkey launches) falls through to `HomeView` unchanged.

`RecordController.mc`'s shared `record()` helper now takes the
`exitOnDismiss` flag directly (previously hardcoded `false`) and returns
the constructed `SuccessView` instead of pushing it; the existing
`recordDiaper()`/`recordBottle()` entry points wrap it in a `pushView()`
push as before, and the new `recordDiaperInitialView()` wraps it in
`asInitialView()` instead. `recordBottle()`'s signature gained the same
`exitOnDismiss` parameter (its one caller, `BottleConfirmDelegate.confirm()`,
now passes `true` or `false` depending on `view.exitOnConfirm`).

Verified with 4 new `BabyDaybookAppTest` cases (constructing a
`BabyDaybookApp` directly and setting the now-public
`launchedFromComplication` field, since it's a plain instance var rather
than something only reachable through `onStart()`'s `Dictionary` argument):
Wet and Dirty each route to a `SuccessView` with `exitOnDismiss` and the
right label, Bottle routes to a `BottleConfirmView` with `exitOnConfirm`,
and `null` falls back to `HomeView`. These don't hit `WatchUi.pushView()`
(the routed-to views are only *constructed and returned*, matching the
existing `SuccessViewTest`/`BottleConfirmViewTest` pattern of constructing
views directly outside a live view stack), so -- unlike
`recordDiaper()`/`recordBottle()`'s own push step -- this routing logic is
fully unit-testable. All 4 new cases pass, and the full suite (89/89 across
every `*Test.mc` module) still passes, via `monkeydo BabyDaybookTest.prg
fenix7 -t`. Confirmed a normal build succeeds for all three real device IDs
(`fenix7`, `fenix7s`, `fenix7x`), that a type-check level 2 ("Informative")
build is clean, and that `monkeydo BabyDaybook.prg fenix7` still launches
without a new `CIQ_LOG.YML` crash entry (normal, non-complication launch).

The live verification this task explicitly calls for -- tapping each of the
three published complications on a subscribing watch face (or via the
simulator's exitTo-equivalent) and confirming Wet/Dirty show the checkmark
and auto-exit after ~2s while Bottle opens the stepper directly, CONFIRM
shows the checkmark and exits, and BACK exits with nothing recorded -- was
**not** driven live in this environment: same missing Screen Recording/
Accessibility permission noted throughout this file (confirmed again here:
`osascript`'s `System Events` can list processes but errors with "not
allowed assistive access" when asking for the simulator process's windows).
The "Simulator caveat" note already lived in this file's own
[Glance launch mode](#glance-launch-mode) section from before this task
started (the simulator defaults `Complications.exitTo` taps to glance-mode
launch; set **Glance Launch Mode** to **Launch in Normal Mode** to test this
routing for real). A real click-through of all three complication launch
paths is still recommended before treating this task's `test`/`commit`
steps as fully closed.
