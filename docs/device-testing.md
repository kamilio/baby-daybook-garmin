# On-watch verification checklist

A hands-on pass for the physical Fenix 7 after sideloading (see
[`INSTALL.md`](../INSTALL.md) for provisioning/build/install steps first).
The simulator (`docs/simulator-testing.md`) can code-verify almost
everything except two things it has no model of at all: bridging requests
through Garmin Connect Mobile over real Bluetooth, and rendering/tap-routing
on an actual third-party CIQ watch face. This checklist exists for those
gaps, plus anything else that only shows up on real hardware (button
behavior with water lock engaged, real reboot/token persistence, battery
drain).

Run through top to bottom after any release build meant for daily use, or
after any change touching `RecordController`, `SyncQueue`, `TokenClient`,
`BackgroundServiceDelegate`, `GlanceView`, or `ComplicationsPublisher`.

## Install

- [ ] App appears in the watch's app list within a few seconds of copying
      the `.prg` to `/GARMIN/APPS/` (file disappears from that folder —
      normal, not a failed transfer).
- [ ] Launching it shows the Home view, not the `IQ!` crash icon. If it
      crashes, check `/GARMIN/APPS/LOGS/CIQ_LOG.yml` per `INSTALL.md`
      §4 before re-testing anything below.

## Touch recording

- [ ] One tap on the Wet zone records immediately and pushes the
      Success view ("Wet", a timestamp, "Synced"/"Queued").
- [ ] One tap on the Dirty zone does the same for Dirty.
- [ ] Tapping Bottle pushes the confirm screen (prefilled with the last
      amount used, or the configured default on first use); confirming
      takes exactly two taps total (Bottle, then confirm) and records;
      backing out of the confirm screen records nothing.
- [ ] With touch disabled (water lock engaged — swipe down from the watch
      face or the usual water-lock gesture for the installed watch face),
      Up/Down moves the highlight ring between zones, START activates the
      highlighted zone (Wet/Dirty record immediately; Bottle pushes the
      confirm screen the same as a tap would), and BACK exits the current
      view. Every action reachable by tap must also be reachable this way.

## Real network path

- [ ] With the paired phone nearby and Garmin Connect Mobile running, a
      Wet/Dirty/Bottle recording made on the watch appears in the Baby
      Daybook phone app within a few seconds — confirms the request
      actually bridges through Connect Mobile's Bluetooth link to
      Firestore, which the simulator cannot exercise (it has no phone-side
      bridge and ships with an empty `refreshToken`/`babyUid` by design).
- [ ] The Home view's pending-count badge (small arc + number, bottom of
      screen) drops to 0 shortly after each of these recordings.

## Offline queue

- [ ] Put the phone in airplane mode (or otherwise cut the Bluetooth
      link), then record a Wet, a Dirty, and a Bottle. Each Success view
      shows "Queued", not "Synced".
- [ ] Home view's pending-count badge shows 3 (or accumulates correctly if
      other items were already queued).
- [ ] Reconnect the phone. Watch the badge drain to 0 without any further
      taps.
- [ ] Check the Baby Daybook phone app: exactly one document per recording
      — no duplicates. (Each queued item keeps the same
      `<epoch-ms>-<counter>` document id across every retry, so a retried
      commit upserts the same Firestore document rather than creating a
      second one.)

## Background sync

- [ ] Record a Wet/Dirty/Bottle while offline (as above), then close the
      app (press BACK out to the watch face, or let it time out) — do not
      leave it foregrounded.
- [ ] Restore connectivity.
- [ ] Wait one full sync interval (15 minutes by default —
      `syncIntervalMinutes` in `properties.xml`/the `.SET` file).
- [ ] Reopen the app: pending-count badge reads 0 and the recording is
      present in the phone app, with no taps or app-open needed in
      between to trigger the flush.

## Token rotation

- [ ] After the watch has been in normal use for a few days (so the
      original build-time `refreshToken` has rotated at least once via
      normal use), reboot the watch (power off/on, not just an app
      restart).
- [ ] Open the app and record a Wet or Dirty. It should sync normally,
      confirming the rotated token — not the one baked into the
      `.prg` at build time — was persisted to `Application.Storage` and
      survived the reboot.

## Glance and complications

- [ ] Swipe to the app's glance (from the watch face's glance list/widget
      loop). It shows a one-line summary ("B 2h · W 45m · D 3h" style) with
      per-action ages, plus a sync badge — matching the actual last-event
      times/queue state, not stale placeholder text.
- [ ] Selecting the glance opens the Home view.
- [ ] On a CIQ watch face that supports third-party complications (stock
      Garmin faces cannot show these — see `INSTALL.md` §6), assign a
      complication slot to each of Bottle/Wet/Dirty. All three appear on
      the face.
- [ ] Tapping the Wet or Dirty complication launches straight into the
      Success view for that action (already recorded, not just Home).
      Tapping the Bottle complication launches straight into the confirm
      screen; confirming there exits back to the watch face rather than
      to Home.

## Battery

- [ ] With the default 15-minute sync interval and normal daily use (a
      handful of recordings), battery drain over 48 h is not noticeably
      worse than the watch's baseline drain with no CIQ app installed. A
      large, sudden drop points at a runaway background wake — check
      `CIQ_LOG.yml` and `BackgroundServiceDelegate`'s wall-clock budget
      before shipping a build that fails this.
