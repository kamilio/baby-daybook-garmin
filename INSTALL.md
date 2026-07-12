# Installing Baby Daybook on a Fenix 7

Owner's guide for provisioning and sideloading this personal Connect IQ app
onto a Fenix 7 / 7S / 7X (or Pro variant). This is a private sideload, never
published to the Connect IQ store — there is no Garmin Connect settings UI for
it, so every value it needs has to be baked in before the first install. This
doc is self-contained; you shouldn't need to read `app/DEVELOPMENT.md` or
`PLAN.md` to get the watch running, though they cover the toolchain setup and
design decisions in more depth if something here doesn't match what you see.

## 1. Provisioning: get your refresh token and baby UID

The watch authenticates to Firebase the same way the Baby Daybook Android app
does, using a refresh token — there's no on-watch login flow. You obtain that
token once, on your computer, using the `baby-daybook` CLI from
[`baby-daybook-sdk`](../baby-daybook-sdk/):

```sh
baby-daybook login apple
```

This opens a temporary browser profile, walks you through Sign in with Apple,
and persists a session to `~/.config/baby-daybook/auth.json` (mode `0600`,
directory mode `0700`). Open that file and copy the `refreshToken` value —
it's a long string, a couple hundred characters.

Then get your baby's UID:

```sh
baby-daybook babies list --output json
```

Copy the `uid` field for the baby you want to track.

Paste both values into `app/resources/properties.xml`:

```xml
<property id="refreshToken">AMf-vBx...</property>
<property id="babyUid">abc123...</property>
```

**Why this has to happen before the build, not after install:** Garmin
Connect Mobile can push settings changes to *store-published* Connect IQ
apps, but it has no mechanism to configure a sideloaded app at all — a
sideload only ever gets whatever was compiled into it. So the refresh token
has to be correct in `properties.xml` at build time.

That said, the baked-in value only has to be valid at *first launch*.
Firebase rotates the refresh token every time it's used, and the watch
persists each new rotated token to `Application.Storage` (see
`source/Config.mc` / `source/TokenClient.mc`) — from then on the watch reads
its own stored, freshly-rotated token instead of the one shipped in the
`.prg`. So you provision once, not on every rebuild.

Never commit real values in `properties.xml` — it holds a personal secret
once filled in. If you rebuild for a code change unrelated to credentials,
either keep your local checkout dirty with the real values, or restore the
empty defaults before pushing/sharing the repo.

## 2. Build

Requires the Connect IQ SDK **>= 7.4.3** (current Fenix firmware won't
install `.prg` files built with an older SDK) and `monkeyc` on your `PATH`.
See `app/DEVELOPMENT.md` if you haven't installed the SDK or generated a
signing key yet.

From `app/`, build the variant matching your exact watch model — device
binaries are not interchangeable between profiles, and the wrong one will
simply fail to install (see Troubleshooting below):

```sh
# Fenix 7 (non-Pro)
monkeyc -d fenix7  -f monkey.jungle -o bin/BabyDaybook.prg -y ../keys/developer_key.der

# Fenix 7S (non-Pro)
monkeyc -d fenix7s -f monkey.jungle -o bin/BabyDaybook.prg -y ../keys/developer_key.der

# Fenix 7X (non-Pro)
monkeyc -d fenix7x -f monkey.jungle -o bin/BabyDaybook.prg -y ../keys/developer_key.der

# Fenix 7 Pro / 7S Pro / 7X Pro
monkeyc -d fenix7pro  -f monkey.jungle -o bin/BabyDaybook.prg -y ../keys/developer_key.der
monkeyc -d fenix7spro -f monkey.jungle -o bin/BabyDaybook.prg -y ../keys/developer_key.der
monkeyc -d fenix7xpro -f monkey.jungle -o bin/BabyDaybook.prg -y ../keys/developer_key.der
```

Check your exact model on the watch under **Settings → System → About** if
you're not sure which of these six it is.

`-y ../keys/developer_key.der` signs the build with the self-generated RSA-4096
key in `keys/` (see `app/DEVELOPMENT.md` for how it was generated). Every
sideloaded `.prg` must be signed — an unsigned or wrong-key `.prg` won't
install (again, see Troubleshooting).

Confirm the build succeeded: `monkeyc` prints `BUILD SUCCESSFUL` and
`bin/BabyDaybook.prg` exists.

## 3. Install over USB

Newer Fenix 7 firmware exposes the watch as an MTP device on macOS (not a
plain USB drive), so Finder alone won't show it. Use one of:

- [OpenMTP](https://openmtp.ganeshrvel.com/) (free, open source), or
- Android File Transfer (Google's official MTP client, also works for Garmin
  devices on macOS)

Connect the watch by USB cable, open one of those apps, and browse to
`/GARMIN/APPS/`. Copy `bin/BabyDaybook.prg` into that folder.

The watch installs the app within a few seconds of the copy — you'll
typically see the `.prg` file **disappear** from `/GARMIN/APPS/` once
installed. This is normal Garmin behavior, not a failed transfer; the watch
consumes the file during installation. If you want to confirm it worked,
check the watch's app list (or see Troubleshooting below if you're not sure).

**Removing the app** is not done by deleting a file over USB — do it on the
watch itself: open the **Connect IQ Store** app on the watch → **Installed**
→ select Baby Daybook → **Delete**.

## 4. Troubleshooting

If the app doesn't appear after copying the `.prg`, or the watch shows a
crash/error icon when you launch it, check the on-watch install log:

```
/GARMIN/APPS/LOGS/CIQ_LOG.yml
```

(browse to it over MTP the same way you copied the `.prg`, and open it in a
text editor). Common entries:

- **Signature mismatch** — the `.prg` wasn't signed with the same key this
  watch has seen before for this app's UUID, or wasn't signed at all. Rebuild
  with `-y ../keys/developer_key.der` and reinstall.
- **Device mismatch** — the `.prg` was built for the wrong device profile
  (e.g. a `fenix7pro` build copied to a plain `fenix7`). **This failure mode
  is silent at the copy step** — the file still disappears from
  `/GARMIN/APPS/` as if it installed, but the app never actually appears on
  the watch. If Baby Daybook doesn't show up after installing, this
  mismatch is the first thing to check in `CIQ_LOG.yml`; the fix is
  rebuilding with the `-d` value matching your exact watch model (Step 2).

## 5. Updating values without a rebuild

Rebuilding just to change the sync interval or a bottle amount default is
slow. Connect IQ lets you edit already-installed property values via a
`.SET` file instead:

1. Launch the Connect IQ simulator (`connectiq &`) and load the build in it:
   `monkeydo bin/BabyDaybook.prg fenix7` (swap the device ID to match).
2. Open the simulator's **Settings** editor for the running app (simulator
   menu bar) — it presents the same fields as `app/resources/settings.xml`
   — and edit the values you want to change, then save.
3. This produces a `.SET` file (same base name as the `.prg`, e.g.
   `BabyDaybook.SET`; on macOS the simulator's own copy lives under
   `$TMPDIR/com.garmin.connectiq/GARMIN/APPS/SETTINGS/`). Copy that file to
   `/GARMIN/APPS/SETTINGS/` on the watch over USB/MTP, keeping the exact
   filename the installed `.prg` uses.
4. The watch picks up the new values on its next launch of the app — no
   reinstall needed.

This only changes values already declared in `settings.xml` (the tuning
knobs, and — in a pinch — the refresh token/baby UID themselves if you need
to re-provision without rebuilding); it can't add new properties or change
code.

## 6. Optional: hotkey and complications

**Hotkey:** you can assign Baby Daybook to one of the watch's physical
button shortcuts from the on-watch **Connect IQ Store → Installed → Baby
Daybook** menu, or via Garmin Connect Mobile's device settings, the same way
you'd assign any other CIQ app to a button.

**Complications:** Baby Daybook publishes three tap-to-track complications
(last bottle / wet / dirty). These only work if you also install a **CIQ
watch face that supports third-party complications** — Garmin's stock/
pre-installed watch faces cannot display or route taps to another app's CIQ
complications; that's a platform limitation, not a bug in this app. Install
a store watch face described as supporting "configurable" or "CIQ"
complication slots, then assign one of its complication slots to Baby
Daybook's Bottle/Wet/Dirty complication from the watch face's own
configuration screen.
