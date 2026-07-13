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
