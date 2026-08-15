# Garmin provisioning page

This static page is opened by the watch through Connect IQ's OAuth hand-off.
It implements Baby Daybook's native Apple authentication flow without an
application server:

1. Open Apple's authorization endpoint with Baby Daybook's registered service
   ID and callback.
2. Paste the one-time `intent://callback…` address returned by Apple.
3. Exchange that credential directly with Firebase Identity Toolkit.
4. Read the signed-in account's baby profiles directly from Firestore.
5. Return the chosen baby UID and rotating refresh token to the watch through
   `connectiq://oauth`.

The Apple credential exists only in page memory. The page stores the selected
baby UID and rotating Firebase refresh token in local browser storage so older
watch versions can complete their Connect IQ browser sync. Nothing is
submitted to GitHub Pages.

GitHub Actions publishes this directory to:

`https://kamilio.github.io/baby-daybook-garmin/`

The `?sync=1` browser sync fallback sends its compact event batch to the same
Fly `/garmin/sync` relay used by current watch builds and saves the rotated
refresh token returned by the relay. Only a complete relay acknowledgement is
returned to the watch. The static site never writes activity records directly
to Firestore, so the relay remains responsible for native record shape and
preserving upstream deletions.
