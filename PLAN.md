---
$schema: https://poe-platform.github.io/poe-code/schemas/plans/pipeline.schema.json
kind: pipeline
version: 1

tasks:
  - id: setup-ciq-toolchain
    title: Install Connect IQ toolchain and generate developer key
    prompt: |
      Set up the Garmin Connect IQ development toolchain for a sideloaded
      personal app in baby-daybook-garmin/.

      - Install the Connect IQ SDK (>= 7.4.3 — required for sideloads on
        current Fenix firmware) via the Connect IQ SDK Manager, and make
        `monkeyc` and the simulator (`connectiq` / `monkeydo`) runnable from
        the shell. macOS host.
      - Download the Fenix 7 device profiles (fenix7, fenix7s, fenix7x) in
        the SDK Manager.
      - Generate the signing key pair (required — every .prg must be signed
        with a self-generated RSA-4096 key, no Garmin registration needed):
        `openssl genrsa -out developer_key.pem 4096` then
        `openssl pkcs8 -topk8 -inform PEM -outform DER -nocrypt
        -in developer_key.pem -out developer_key.der`.
        Store both under baby-daybook-garmin/keys/ and gitignore that
        directory.
      - Write baby-daybook-garmin/app/DEVELOPMENT.md documenting: SDK paths,
        key location, the build command
        `monkeyc -d <deviceId> -f monkey.jungle -o BabyDaybook.prg -y
        ../keys/developer_key.der`, and how to launch the simulator.
      - Verify by compiling any SDK sample for `fenix7`.
    status:
      implement: done
      commit: done

  - id: verify-wire-format
    title: Verify bottle/diaper Firestore wire format against the real account
    prompt: |
      Determine the exact Firestore field encoding the Baby Daybook Android
      app uses for bottle and diaper events, so the Garmin app writes
      byte-compatible documents.

      Tools available in this repo: the JS SDK at baby-daybook-sdk/ with CLI
      (`baby-daybook`), using the persisted session at
      ~/.config/baby-daybook/auth.json. Activities live in Firestore at
      babyData/babyUid_<BABY>/dailyActions/<uid>, project baby-daybook-app.

      - Run `baby-daybook babies list --output json` to get the baby UID,
        then `baby-daybook activities list <BABY_UID> --output json` and
        extract one `bottle` and one `diaper_change` record created by the
        phone app.
      - Read baby-daybook-sdk/src/firestore.ts (`encodeFields`) to determine
        how numbers are encoded on the wire (integerValue vs doubleValue),
        since the CLI output is decoded JSON. If ambiguous, fetch one raw
        document via the Firestore REST API using an ID token obtained the
        same way the SDK does.
      - Answer specifically: (a) wire type of `volume` on bottle records;
        (b) full field set the app writes for a quick-add `diaper_change`
        (does it set `groupUid`, `endMillis`, `duration`, `amountUnit`?);
        (c) full field set for a bottle record; (d) confirm `svt` is set
        server-side.
      - Write the findings, including one raw sample document per type with
        secrets redacted, to baby-daybook-garmin/docs/wire-format.md. Do not
        write or modify any data in the account.
    status:
      implement: done
      commit: done

  - id: scaffold-app
    title: Scaffold the Connect IQ device app project
    prompt: |
      Create a Connect IQ device app (watch-app type) skeleton at
      baby-daybook-garmin/app/ named "Baby Daybook".

      - manifest.xml: target devices fenix7, fenix7s, fenix7x, fenix7pro,
        fenix7spro, fenix7xpro; minApiLevel 4.2.0; permissions
        Communications, Background, ComplicationPublisher; a generated app
        UUID.
      - monkey.jungle, resources/ (strings.xml, a simple placeholder
        launcher icon), source/ with BabyDaybookApp.mc (AppBase) returning a
        placeholder main view + BehaviorDelegate.
      - Must compile with
        `monkeyc -d fenix7 -f monkey.jungle -o bin/BabyDaybook.prg
        -y ../keys/developer_key.der`
        (key from baby-daybook-garmin/keys/, created by earlier setup) and
        launch in the fenix7 simulator showing the placeholder screen.
      - Add baby-daybook-garmin/app/.gitignore for bin/ and *.prg.
    status:
      implement: done
      test: done
      commit: done

  - id: app-properties
    title: Define build-time properties for secrets and tuning
    prompt: |
      In the Connect IQ app at baby-daybook-garmin/app/, define properties
      (resources/properties.xml + settings.xml) for a sideloaded personal
      app. Garmin Connect cannot edit settings of sideloaded apps, so these
      are baked in at build time; runtime overrides live in
      Application.Storage.

      Properties:
      - refreshToken (string, empty default) — Firebase refresh token,
        ~200 chars; mark as secret/password type in settings.xml.
      - babyUid (string, empty default).
      - syncIntervalMinutes (number, default 15; runtime minimum 5 — the
        Connect IQ temporal-event floor).
      - defaultBottleMl (number, default 120), bottleStepMl (default 10),
        bottleMinMl (default 30), bottleMaxMl (default 300).

      Add source/Config.mc with typed getters that read
      Application.Properties but prefer an Application.Storage override
      where one exists (the rotating refresh token is persisted to Storage
      at runtime and must win over the baked-in default). Document in
      DEVELOPMENT.md how to set real values before building, and the
      alternative no-rebuild path: editing settings in the simulator and
      copying its generated .SET file to /GARMIN/APPS/SETTINGS/ on the
      watch with the same filename as the .prg.
    status:
      implement: done
      test: done
      commit: done

  - id: storage-module
    title: Persistent storage module
    prompt: |
      In baby-daybook-garmin/app/source/, add Store.mc wrapping
      Toybox.Application.Storage with typed accessors for the app's
      persistent state. Keys:

      - authCache: { "idToken", "expiresAtMillis", "userId",
        "refreshToken" } — refreshToken here overrides the build-time
        property once Firebase rotates it.
      - syncQueue: array of pending event dictionaries (see queue task).
      - lastEventMillis: dictionary keyed by "bottle" / "wet" / "dirty" —
        feeds complications and the glance.
      - lastBottleMl: number or null.
      - lastAction: string — home screen highlight for button navigation.

      Guard every read against null/malformed values with safe defaults
      (Storage survives app updates; shape may drift between builds). Keep
      the module free of UI imports and annotate it (:background)-safe —
      the background sync service shares these keys (Storage is shared
      foreground/background on CIQ >= 3.2). Values are capped at 32 KB
      each; the queue accessor must re-read from Storage before every
      mutation (last-writer-wins, no locking).
    status:
      implement: done
      test: done
      commit: done

  - id: auth-client
    title: Firebase token client (securetoken exchange)
    prompt: |
      In baby-daybook-garmin/app/source/, add TokenClient.mc implementing
      the Firebase ID-token lifecycle over
      Communications.makeWebRequest. Must be usable from foreground and
      background ((:background)-safe, no UI imports).

      getIdToken(callback):
      - Return the cached token from Storage (key authCache) when
        expiresAtMillis is more than 60 s away.
      - Otherwise POST
        https://securetoken.googleapis.com/v1/token?key=AIzaSyDIjjUS-7888pKeaVgNM1g2lSLOX4i6Na8
        with Content-Type application/x-www-form-urlencoded, body
        grant_type=refresh_token&refresh_token=<token>, and headers
        X-Android-Package: com.drillyapps.babydaybook and
        X-Android-Cert: F63803E1E071269A0DDAB71664A1A55F6F27F8D4
        (the API key rejects requests without these Android app
        identification headers).
      - Refresh token source: Storage authCache.refreshToken, falling back
        to the build-time refreshToken property (Config.mc).
      - On success ({ id_token, refresh_token, user_id, expires_in }):
        persist id_token, expiresAtMillis = now + expires_in*1000,
        user_id, and ALWAYS the returned refresh_token (Firebase rotates
        it; losing a rotated token bricks auth until re-provisioning).
      - Error mapping for the callback: HTTP 400/401 on the token endpoint
        means the refresh token is invalid -> AUTH_INVALID (UI shows
        "check token"); network errors / 5xx -> RETRYABLE.
      - Also expose invalidateIdToken() (used for one 401-triggered
        retry by the sync queue) and getUserId().
    status:
      implement: done
      refactor: done
      test: done
      commit: done

  - id: firestore-client
    title: Firestore commit client for event writes
    prompt: |
      In baby-daybook-garmin/app/source/, add FirestoreClient.mc with
      commitEvent(event, idToken, callback), (:background)-safe, no UI
      imports. It performs the single write the app needs:

      POST https://firestore.googleapis.com/v1/projects/baby-daybook-app/databases/(default)/documents:commit
      Authorization: Bearer <idToken>, Content-Type: application/json.

      Body (Firestore typed-JSON), where <uid> is the event's queue id and
      doubles as the document ID (retries upsert the same document —
      idempotent by construction):

      { "writes": [ {
          "update": {
            "name": "projects/baby-daybook-app/databases/(default)/documents/babyData/babyUid_<BABY>/dailyActions/<uid>",
            "fields": {
              "uid":           {"stringValue": "<uid>"},
              "userUid":       {"stringValue": "<userId from TokenClient>"},
              "babyUid":       {"stringValue": "<BABY>"},
              "type":          {"stringValue": "bottle" | "diaper_change"},
              "startMillis":   {"integerValue": "<button-press epoch ms as string>"},
              "updatedMillis": {"integerValue": "<epoch ms as string>"},
              "inProgress":    {"booleanValue": false},
              "volume":        <bottle only, only when amount set>,
              "pee":           {"booleanValue": true|false},  // diaper only
              "poo":           {"booleanValue": true|false}   // diaper only
            }
          },
          "updateTransforms": [
            {"fieldPath": "svt", "setToServerValue": "REQUEST_TIME"}
          ]
      } ] }

      - integerValue values are JSON strings, not numbers.
      - The numeric wire type for `volume` and any extra diaper fields must
        match baby-daybook-garmin/docs/wire-format.md (written by an earlier
        verification task against the real account); read it and follow it.
      - Ignore the commit response body; report only status class to the
        callback: 2xx OK, 401 UNAUTHENTICATED, 400/403 PERMANENT,
        everything else / network RETRYABLE.
    status:
      implement: done
      refactor: done
      test: done
      commit: done

  - id: sync-queue
    title: Offline queue with flush and error taxonomy
    prompt: |
      In baby-daybook-garmin/app/source/, add SyncQueue.mc — the offline-
      first heart of the app, (:background)-safe, building on Store.mc,
      TokenClient.mc, and FirestoreClient.mc.

      - enqueue(event): stamp id = "<epoch-ms>-<counter>" (unique; it is
        also the Firestore document ID), startMillis = button-press time,
        attempts = 0; re-read the queue from Storage, append, persist, then
        trigger flush(). Cap the queue at 100 items (drop oldest, surface a
        warning flag).
      - flush(): single request in flight at a time; send oldest first via
        TokenClient.getIdToken -> FirestoreClient.commitEvent. Stop on the
        first failure — no retry storms on-watch.
      - Result handling: OK -> remove item, update lastEventMillis for the
        event's action, continue with next item. UNAUTHENTICATED ->
        TokenClient.invalidateIdToken(), retry that item exactly once; if
        the token refresh itself fails with AUTH_INVALID -> pause the queue
        and set a needsToken flag for the UI. PERMANENT (400/403) -> drop
        the item and set a lastError flag shown once. RETRYABLE -> keep the
        item, increment attempts, stop flushing.
      - Expose pendingCount() for the UI badge and an onChanged callback
        hook so views can refresh.
      - Flush triggers: enqueue, app start, and the background temporal
        event (wired in a later task).
      - Always re-read the queue from Storage before mutating (the
        background process shares it; last-writer-wins).
    status:
      implement: done
      refactor: done
      test: done
      commit: done

  - id: home-view
    title: Home screen with three tap zones
    prompt: |
      In baby-daybook-garmin/app/source/, implement HomeView.mc +
      HomeDelegate.mc (BehaviorDelegate) — the app's main screen for a
      round touchscreen Fenix 7 (260x260 MIP, also 240 and 280 variants;
      use dc dimensions, no hardcoded pixels).

      Layout — three full-width horizontal tap zones:
        top:    Bottle (baby-bottle icon + "BOTTLE")
        middle: Wet    (droplet icon + "WET")
        bottom: Dirty  (poo icon + "DIRTY")
      Middle zone gets the widest band; top/bottom zones inset their
      content for the round display's clipped corners. Draw a small
      pending-sync badge ("N" with a sync glyph) near the bottom edge when
      SyncQueue.pendingCount() > 0, and a subtle "check token" state when
      the queue is paused for auth.
      Icons: use simple drawn shapes or bundled bitmaps — no emoji fonts on
      Fenix MIP displays.

      Input:
      - onTap: hit-test by zone. Wet/Dirty -> invoke the instant-record
        action (separate task wires it; call a RecordController stub for
        now). Bottle -> push the bottle confirm view (stub until built).
      - Button fallback (touch is disabled in water-lock/gloves): Up/Down
        moves a highlight ring between zones (wrapping), START activates
        the highlighted zone, BACK exits. Initial highlight =
        Store.lastAction, persisted on every activation.
      Verify all of it in the fenix7 simulator, touch and buttons.
    status:
      implement: done
      test: done
      commit: done

  - id: diaper-instant-record
    title: Instant diaper recording and success screen
    prompt: |
      In baby-daybook-garmin/app/source/, implement the instant-record path
      for the two diaper actions plus the shared success screen.

      RecordController.mc:
      - recordDiaper(kind): kind "wet" -> {type: "diaper_change", pee: true,
        poo: false}, "dirty" -> {pee: false, poo: true}; startMillis = now.
        Enqueue via SyncQueue (never wait for HTTP — the queue is the
        source of truth), update Store.lastEventMillis and Store.lastAction,
        then show SuccessView.
      - recordBottle(volumeOrNull): {type: "bottle", volume when set};
        same flow (the confirm view calls this).

      SuccessView.mc:
      - Big checkmark, action label ("Wet diaper" / "Dirty diaper" /
        "Bottle 120 ml" / "Bottle"), the recorded wall-clock time, and a
        status line: "Synced" once the queue confirms, else "Queued".
      - Auto-dismiss after ~2 s (Timer): pop back to the home view, or
        exit the app entirely when the flow started from a complication
        launch (flag passed in).
      - No undo affordance — mistakes are deleted in the phone app.
      Wire the home view's Wet/Dirty zones to RecordController and verify
      in the simulator, including the offline case (simulator network off
      -> "Queued").
    status:
      implement: done
      test: done
      commit: done

  - id: bottle-confirm-view
    title: Bottle confirm screen with amount stepper
    prompt: |
      In baby-daybook-garmin/app/source/, implement BottleConfirmView.mc +
      delegate — the only action with a confirm step (diapers record
      instantly and never show this screen).

      Layout (round Fenix 7 touchscreen): "Bottle" title with icon; a
      centered amount line "<N> ml" flanked by large "−" and "+" tap
      targets; a CONFIRM button zone at the bottom.

      Behavior:
      - Prefill with Store.lastBottleMl, else defaultBottleMl config
        (120). Step by bottleStepMl (10) within bottleMinMl..bottleMaxMl
        (30..300) from config.
      - Stepping below the minimum shows "— ml" = record without an
        amount (amount is optional; it can be filled in on the phone).
      - Touch: tap −/+ steps, tap CONFIRM records. Buttons: Up/Down step,
        START confirms, BACK cancels (pop, nothing saved). Holding −/+
        (or repeated presses) must feel responsive.
      - CONFIRM calls RecordController.recordBottle(volume or null); only
        a confirmed record with an amount updates Store.lastBottleMl; the
        SuccessView then shows "Bottle <N> ml" or "Bottle".
      Wire the home view's Bottle zone to push this view and verify both
      input modes in the simulator.
    status:
      implement: done
      test: done
      commit: done

  - id: background-sync
    title: Configurable periodic background sync
    prompt: |
      In baby-daybook-garmin/app/, add the periodic background flush using
      Connect IQ temporal events.

      - BackgroundService.mc: a ServiceDelegate whose onTemporalEvent()
        reads the shared sync queue (Application.Storage is shared with
        the foreground app on CIQ >= 3.2), flushes pending items oldest-
        first via the existing TokenClient/FirestoreClient/SyncQueue code,
        then calls Background.exit(). Budget: hard 30-second wall clock
        and ~28 KB usable memory — post ONE item per wake if memory is
        tight (BLE_REQUEST_TOO_LARGE from makeWebRequest is the
        out-of-memory symptom), leaving the rest for the next wake.
      - Annotate the service, AppBase, and every module it touches
        (Store, Config, TokenClient, FirestoreClient, SyncQueue) with
        (:background); keep all UI imports out of that dependency chain.
        Return the delegate from AppBase.getServiceDelegate(). The
        Background permission is already in the manifest.
      - Registration: on every app start, read syncIntervalMinutes from
        config (default 15), clamp to >= 5 (platform floor — smaller
        values throw InvalidBackgroundTimeException), and
        Background.registerForTemporalEvent(new Time.Duration(minutes*60)).
        Re-registering overwrites the previous schedule, which is what
        makes the interval configurable. Skip re-registration when
        getTemporalEventRegisteredTime() already matches.
      - Verify in the simulator (it can fire temporal events on demand):
        enqueue offline, fire the background event, confirm the queue
        drains and lastEventMillis updates.
    status:
      implement: done
      refactor: done
      test: done
      commit: done

  - id: complications-publish
    title: Publish per-action complications with time since last event
    prompt: |
      In baby-daybook-garmin/app/, publish three Connect IQ complications
      (Toybox.Complications, ComplicationPublisher permission is already in
      the manifest; device apps may publish up to 4): Bottle, Wet, Dirty.

      - Each complication's value is time since Store.lastEventMillis for
        its action, as a compact short label (e.g. "2h", "45m", "—" when
        never recorded), plus a per-action icon and long label
        ("Last bottle" etc.). Define the three complications with distinct
        numeric IDs (0/1/2) in resources.
      - Update all three: after every successful record, on app start, and
        at the end of every background temporal wake (so the displayed age
        stays fresh within the sync interval even when the app is closed).
      - Known platform limit (do not fight it): only CIQ watch faces that
        subscribe can display CIQ-published complications — Garmin's stock
        faces cannot. Note in DEVELOPMENT.md that testing requires a CIQ
        watch face that maps arbitrary CIQ complications.
      - Verify in the simulator with a subscribing test watch face or the
        simulator's complications inspector.
    status:
      implement: done
      test: done
      commit: done

  - id: complication-launch-routing
    title: Route complication taps to instant record or bottle confirm
    prompt: |
      In baby-daybook-garmin/app/source/, handle the app being launched by
      a tap on one of its three published complications (Bottle=0, Wet=1,
      Dirty=2 — a CIQ watch face invokes Complications.exitTo, and the app
      receives the launching complication's identity at startup).

      - In BabyDaybookApp (AppBase), detect the launch source. When
        launched via complication:
        Wet/Dirty -> call RecordController.recordDiaper immediately —
        no home screen — showing only the SuccessView with the exit-after-
        dismiss flag set (auto System.exit ~2 s after the checkmark).
        Bottle -> open BottleConfirmView directly as the initial view;
        CONFIRM shows SuccessView then exits; BACK exits without saving.
      - Normal launches (launcher, glance, hotkey) still open the home
        view.
      - Simulator caveat: exitTo may launch the publisher in glance mode —
        set the simulator's "Glance Launch Mode" to "Launch in Normal
        Mode" when testing; note this in DEVELOPMENT.md.
      - Verify all three complication launch paths in the simulator.
    status:
      implement: done
      test: done
      commit: done

  - id: glance-view
    title: Summary glance
    prompt: |
      In baby-daybook-garmin/app/, add the app's glance (one per app —
      platform limit; it cannot perform actions, only open the app).

      - GlanceView.mc annotated (:glance): line 1 "Baby Daybook"; line 2 a
        compact last-events summary from Store.lastEventMillis, e.g.
        "B 2h · W 45m · D 3h" (single line, glances get roughly a third of
        the screen); append a sync glyph + count when
        SyncQueue.pendingCount() > 0.
      - Register the glance in AppBase.getGlanceView(). Selecting the
        glance opens the app's normal home view (default behavior — no
        extra code beyond returning the initial view).
      - Glance memory budget is small (~32 KB) — the glance code path must
        pull in only Store.mc, not the network stack. Verify in the fenix7
        simulator's glance carousel.
    status:
      implement: done
      test: done
      commit: done

  - id: simulator-e2e
    title: Full simulator end-to-end pass
    prompt: |
      Run a complete end-to-end pass of the Baby Daybook Connect IQ app in
      the fenix7 simulator (app at baby-daybook-garmin/app/, build per
      DEVELOPMENT.md) and fix every defect found. Cover, with both touch
      and button input:

      - Home: three zones render on 240/260/280-px round profiles
        (fenix7s/fenix7/fenix7x), highlight starts on last action, badge
        counts pending items.
      - Wet/Dirty: instant record -> checkmark -> auto-return; queue drains
        when the simulated network is on; "Queued" shown when off.
      - Bottle: prefill, stepping, below-min "— ml" no-amount record, BACK
        cancels without saving, lastBottleMl only updates on confirmed
        amounts.
      - Auth: with an expired cached ID token the first flush refreshes
        then succeeds; with a garbage refresh token the queue pauses and
        the home view shows the check-token state.
      - Offline queue: enqueue 5+ events with network off, re-open the
        app / fire a temporal event, confirm oldest-first drain and
        idempotent document IDs (same id on retry).
      - Background: temporal event fires, drains queue, complications
        update, foreground state stays consistent afterward.
      - Complication launches: all three routes; glance renders and opens
        the app.
      - Settings: export a .SET from the simulator settings editor and
        confirm the documented /GARMIN/APPS/SETTINGS workflow in
        DEVELOPMENT.md matches reality.

      Record the run results (pass/fail per area, bugs fixed) in
      baby-daybook-garmin/docs/simulator-testing.md.
    status:
      test: open
      commit: open

  - id: install-docs
    title: Provisioning and sideload installation guide
    prompt: |
      Write baby-daybook-garmin/INSTALL.md — the complete owner's guide for
      provisioning and sideloading this personal app onto a Fenix 7. It
      must be followable start-to-finish without other docs. Cover:

      1. Provisioning: `baby-daybook login apple` (from baby-daybook-sdk,
         creates ~/.config/baby-daybook/auth.json) and
         `baby-daybook babies list` for the baby UID; where to paste both
         values (refreshToken/babyUid defaults in
         app/resources/properties.xml) and why build-time baking is
         needed (Garmin Connect cannot edit sideloaded apps' settings; the
         watch persists the rotating token in Storage afterwards, so the
         baked value only needs to be valid at first launch).
      2. Build: exact monkeyc command per variant (fenix7/fenix7s/fenix7x
         and Pro IDs), SDK >= 7.4.3 requirement, signing with
         keys/developer_key.der.
      3. Install over USB: newer Fenix firmware exposes MTP on macOS — use
         OpenMTP or Android File Transfer; copy the .prg to /GARMIN/APPS;
         the file disappearing after install is normal; deleting a
         sideload happens in the on-watch CIQ store app -> Installed.
      4. Troubleshooting: /GARMIN/APPS/LOGS/CIQ_LOG.yml (signature/device
         mismatch errors), wrong-device .prg silently not installing.
      5. Updating values without a rebuild: simulator settings editor ->
         .SET file -> /GARMIN/APPS/SETTINGS/ (same filename as the .prg).
      6. Optional: assigning the app to a hotkey on the watch, and that
         complication tap-to-track requires a CIQ watch face that maps CIQ
         complications (stock faces cannot show them).
    status:
      implement: open
      commit: open

  - id: device-test-checklist
    title: On-watch verification checklist
    prompt: |
      Write baby-daybook-garmin/docs/device-testing.md — a hands-on
      checklist for verifying the sideloaded app on the physical Fenix 7
      (the simulator cannot cover Bluetooth bridging or real watch faces).
      Organize as checkboxes with expected outcomes:

      - Install verifies and launches (no IQ! crash icon).
      - Touch recording: wet/dirty one tap, bottle confirm two taps;
        button fallback works with touch disabled (water lock).
      - Real network path: events appear in the Baby Daybook phone app
        within seconds when the phone is nearby (requests bridge through
        Garmin Connect Mobile over Bluetooth).
      - Offline: phone in airplane mode -> records show "Queued"; events
        deliver after reconnect, no duplicates in the phone app (retries
        upsert the same document ID).
      - Background sync: record offline, close the app, restore
        connectivity, wait one sync interval -> queue drains without
        opening the app.
      - Token rotation: after days of use, reboot the watch and confirm
        recording still works (rotated refresh token persisted in
        Storage survived).
      - Glance shows last-event ages; complications appear and tap-launch
        correctly on the chosen CIQ watch face.
      - Battery: no abnormal drain over 48 h with a 15-minute sync
        interval.
    status:
      implement: open
      commit: open
---

# Context

A "baby remote control" for a **Fenix 7 (touchscreen, CIQ API 5.2)**:
actions only, no history, no settings screens, no server. The watch captures
events in one or two taps; the phone app remains the place for everything
else. Personal sideloaded app — never published to the store.

## Scope

**Actions (v1):** 🍼 Bottle (optional ml amount) · 💧 Wet diaper · 💩 Dirty
diaper. Out of scope: sleep tracking, timeline, editing, charts, notes,
multiple children, undo (mistakes are deleted in the phone app).

## Architecture

Baby Daybook has **no REST API** — the JS SDK
([baby-daybook-sdk](../baby-daybook-sdk/)) talks straight to Firebase
(project `baby-daybook-app`), impersonating the Android app. The watch does
the same with exactly two HTTP calls via `Communications.makeWebRequest`
(bridged through Garmin Connect Mobile on the phone):

1. **Token refresh** — `POST securetoken.googleapis.com/v1/token?key=<API_KEY>`
   (form-encoded, headers `X-Android-Package: com.drillyapps.babydaybook`,
   `X-Android-Cert: F63803E1E071269A0DDAB71664A1A55F6F27F8D4`) → 1-hour ID
   token + rotating refresh token (always re-persisted) + `user_id`.
2. **Event write** — Firestore `documents:commit` upserting
   `babyData/babyUid_<BABY>/dailyActions/<uid>` with typed fields
   (`type`/`startMillis`/`volume`/`pee`/`poo`…) and an `svt` REQUEST_TIME
   transform, mirroring the SDK's write path
   ([firestore.ts:55](../baby-daybook-sdk/src/firestore.ts#L55)). The queue
   item id doubles as the document ID → retries are idempotent.

Offline-first: every action is persisted to `Application.Storage` before any
network I/O; the queue is the source of truth. Flushes run on record, app
open, and a configurable temporal background event (default 15 min, platform
floor 5 min).

## UX

- **Home:** three full-width tap zones (Bottle / Wet / Dirty), one tap for
  diapers; button fallback (Up/Down highlight + START) for water-lock.
  Pending-sync badge in the corner.
- **Bottle confirm (bottle only):** last-used ml prefilled, −/+ steps of
  10 ml, below-min = "— ml" (record without amount), CONFIRM records, BACK
  cancels.
- **Success screen:** ✓ + label + time + Synced/Queued, auto-dismiss ~2 s,
  exits the app when launched from a complication.
- **Entry points:** three published complications (one per action;
  Wet/Dirty tap = record immediately, Bottle tap = confirm screen) — these
  require a **CIQ watch face that subscribes** (stock faces can't show CIQ
  complications); one summary glance; optional user-assigned hotkey.

## Key platform facts (verified)

- Fenix 7 = first touch Fenix; supports glances + complication publishing.
  Fenix 6 has neither touch nor complications (moot — device confirmed 7).
- One glance per app; glances can't act, only open the app.
- Sideloads: RSA-4096 self-signed `.prg` over USB (MTP on macOS) to
  `/GARMIN/APPS`; **Garmin Connect cannot edit sideloaded apps' settings**
  → secrets baked into `properties.xml` at build time, Storage overrides at
  runtime; `.SET`-file copy as the no-rebuild alternative; failures logged
  to `/GARMIN/APPS/LOGS/CIQ_LOG.yml`; SDK ≥ 7.4.3 required.
- Background: 5-min temporal-event floor, one registration (re-register to
  change interval), ~28 KB usable / 30 s hard limit, `makeWebRequest`
  allowed, Storage shared with foreground (CIQ ≥ 3.2).

## Open questions

- Which Fenix 7 variant (7 / 7S / 7X / Pro)? Sets the build device ID and
  simulator profile — Settings → System → About.
- Complication tap-to-track watch face: existing store CIQ face that maps
  CIQ complications, or a small companion face as a follow-up?
- `volume` wire encoding + exact quick-add diaper field set: resolved by
  the `verify-wire-format` task against the real account before any
  Firestore code is written.
