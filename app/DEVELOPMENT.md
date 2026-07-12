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
