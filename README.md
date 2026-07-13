# Baby Daybook for Garmin

A private Connect IQ app for recording Baby Daybook bottle and diaper events
from the Garmin fēnix 7 family.

## Provisioning

Open the GitHub Pages setup flow on your phone. Sign in with Apple, copy the
resulting one-time `intent://callback…` address into the provisioning page,
choose the baby, then copy the generated `connectiq://oauth…` setup code.
Paste that complete code into **Connect IQ → My Device → My Apps → Baby
Daybook → Settings → Setup**, save, and sync the watch.

The page exchanges that one-time Apple credential directly with Baby Daybook's
Firebase project, loads the signed-in account's baby profiles, and returns the
selected baby UID plus refresh token into the setup code. The static site has
no application server and does not persist credentials. The watch UI uses
Garmin's native `Menu2` and `Picker` controls.

## Build

Install the Connect IQ SDK and create `keys/developer_key.der` as described in
[`app/DEVELOPMENT.md`](app/DEVELOPMENT.md), then run:

```sh
cd app
monkeyc -d fenix7 -f monkey-beta.jungle \
  -o bin/BabyDaybook-beta-fenix7.prg \
  -y ../keys/developer_key.der -r
```

Export the multi-device beta package with:

```sh
monkeyc -e -f monkey-beta.jungle \
  -o bin/BabyDaybook-beta.iq \
  -y ../keys/developer_key.der -r
```

### Publish a beta quickly

The Garmin Developer portal has no supported publishing CLI. This repository
automates its normal browser upload with Playwright and the installed Chrome;
credentials and cookies remain in a local profile outside the repository.

Install the small automation dependency and sign in once:

```sh
npm install
npm run garmin:login
```

Then build/export the IQ package and publish it:

```sh
npm run garmin:publish -- \
  --version 0.3.0-beta.1 \
  --notes "Native Garmin controls and settings-based provisioning."
```

Use `--dry-run` to validate the package, version, and notes without contacting
Garmin. The default package is `app/bin/BabyDaybook-beta.iq`. Set
`GARMIN_PUBLISH_PROFILE` to use a different local Chrome profile, or
`GARMIN_APP_ID` to target another listing. A failed upload saves a diagnostic
screenshot at `output/playwright/garmin-publish-error.png`.

## GitHub Pages

[`site/`](site/) is deployed by [the Pages workflow](.github/workflows/pages.yml)
to <https://kamilio.github.io/baby-daybook-garmin/> whenever `main` changes.

## Tests

```sh
cd app
monkeyc -d fenix7 -f monkey.jungle \
  -o bin/BabyDaybookTest.prg \
  -y ../keys/developer_key.der -t
monkeydo bin/BabyDaybookTest.prg fenix7 -t
```
