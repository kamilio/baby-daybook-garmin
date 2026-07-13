# Garmin provisioning page

This static page is opened by the watch through Connect IQ's OAuth hand-off.
It does not submit or persist credentials. The browser redirects directly to
`connectiq://oauth`, which the Connect IQ mobile app intercepts and returns to
the watch.

GitHub Actions publishes this directory to:

`https://kamilio.github.io/baby-daybook-garmin/`

Before opening the flow on the watch, copy the locally stored refresh token:

```sh
./scripts/copy-provisioning-token
```

On Apple devices with Handoff enabled, Universal Clipboard makes that token
available to paste in the Connect IQ browser on the phone. The helper never
prints the token.
