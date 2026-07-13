# Baby Daybook for Garmin

A private Connect IQ app for recording Baby Daybook bottle and diaper events
from the Garmin fēnix 7 family.

## Provisioning

The published beta opens a GitHub Pages flow through Garmin's Connect IQ
authentication hand-off. Sign in with Apple in the separate browser page,
copy the resulting one-time `intent://callback…` address, and paste it back
into the provisioning page. This is the same callback mechanism used by the
Baby Daybook SDK's hosted OAuth flow.

The page exchanges that one-time Apple credential directly with Baby Daybook's
Firebase project, loads the signed-in account's baby profiles, and returns the
selected baby UID plus refresh token directly to the watch through
`connectiq://oauth`. The static site has no application server and does not
persist credentials.

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
