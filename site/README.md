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

The Apple credential and Firebase session exist only in page memory. They are
not persisted in browser storage or submitted to GitHub Pages.

GitHub Actions publishes this directory to:

`https://kamilio.github.io/baby-daybook-garmin/`
