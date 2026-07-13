# Baby Daybook for Garmin

A private Connect IQ app for recording Baby Daybook bottle and diaper events
from the Garmin fēnix 7 family.

## Provisioning

The published beta opens a static GitHub Pages form through Garmin's Connect
IQ authentication hand-off. The page makes no network requests and redirects
the credentials directly back to the watch.

Before launching the app on the watch, copy the refresh token created by the
local Baby Daybook CLI:

```sh
./scripts/copy-provisioning-token
```

Paste it into the form on the phone using Universal Clipboard. Victoria's Baby
Daybook UID is prefilled. On completion, the watch stores the credentials and
resumes its pending sync queue.

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
