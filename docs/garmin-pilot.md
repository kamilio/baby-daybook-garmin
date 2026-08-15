# Garmin simulator E2E automation

`tools/garmin-pilot` is the repository's terminal-pilot-style SDK for the
macOS Connect IQ Device Simulator. It wraps the two Garmin-supported command
line entry points (`connectiq` and `monkeydo`) and adds screenshots, physical
button input, normalized touch input, screenshot-change waits, and crash-log
assertions.

## API

```js
import { GarminPilot } from "garmin-pilot";

const pilot = await GarminPilot.launch();
try {
  const watch = await pilot.newSession({
    device: "fenix7",
    prg: "app/bin/BabyDaybook-fenix7.prg",
  });

  await watch.screenshot({ path: "output/home.png", region: "window" });
  await watch.press("Down");
  await watch.press("Start");
  await watch.tap({ x: 0.5, y: 0.7 });
  await watch.swipe({ x: 0.5, y: 0.8 }, { x: 0.5, y: 0.2 });
  await watch.assertNoNewCrash();
} finally {
  pilot.close();
}
```

`pilot.close()` terminates the attached `monkeydo` process group. It does not
quit the shared Connect IQ Simulator.

## Execution modes

| Operation | Steals focus | Accessibility | Intended use |
|---|---:|---:|---|
| `launch`, `newSession` | No | No | Load a simulator build |
| `screenshot(region: "window")` | No | No | Stable full-window visual assertion |
| `screenshot(region: "device")` | No | No | Stable display-area crop |
| `waitForScreenshotChange` | No | No | Render/change synchronization |
| `assertNoNewCrash` | No | No | Compare `CIQ_LOG.YML` to session baseline |
| `press`, `tap` | Yes | Yes | Optional black-box input smoke tests |
| `swipe` | Yes | Yes | Experimental synthesized drag |
| `screenshot(region: "framebuffer")` | Yes | Yes | Exact native framebuffer export |

Garmin's SDK exposes no headless button/touch injection command. The simulator
canvas has no Accessibility children, and process-targeted CoreGraphics mouse
events are ignored by it. Synthesized button clicks and taps work as optional
black-box canaries, but synthesized drags are not consistently recognized.
Consequently, feature acceptance uses the simulator-only scenario entry point
described below. Interactive tests must run on an idle desktop, a separate
macOS login session, or a VM.

## Mouse-free scenario tests

`app/monkey-e2e.jungle` builds a separate application UUID whose entry point
selects a named production view. `scripts/build-scenario.mjs` performs that
build in a private temporary directory and replaces only the temporary
`ScenarioConfig.mc`. The production manifest, entry point, and binary are
unchanged.

```sh
# Build, launch, capture, and crash-check one state without focusing the app.
npm run e2e:scenario -- bottle-amount fenix7

# Capture every registered state on fēnix 7, 7S, and 7X.
npm run e2e:scenario-matrix
```

Add a scenario to the allow-list in `scripts/build-scenario.mjs`, then route it
in `BabyDaybookE2EApp.getInitialView()`. Prefer constructor-injected fixture
data for new views; use simulator storage only when the production view reads
storage by design. Each capture uses the deterministic `device` crop and fails
if the Connect IQ crash log changes.

## Commands

```sh
# Produce a local ignored build using the persisted Baby Daybook login.
npm run e2e:auth-build

# Background-safe load, screenshots, and crash assertion.
npm run e2e:background

# Interactive Down-button assertion.
npm run e2e:smoke

# Interactive button + tap verification against Garmin's Input sample.
npm run e2e:input

# Optional diagnostic; Garmin may not recognize the synthesized drag.
GARMIN_PILOT_TEST_SWIPE=1 npm run e2e:input

# Package verification.
npm run garmin-pilot:test
npm run garmin-pilot:build
```

## Restoring the normal-Chrome CLI session

Garmin Store authentication uses the Playwright extension attached to the
user's normal Chrome profile. It never creates an automation-only browser
profile. The named attachment can be restored idempotently and left waiting
in the background while the extension is inactive:

```sh
npm run garmin:browser
npm run garmin:browser:status
```

Once the extension is active, `garmin:browser` reuses the
`garmin-developer` session and navigates it to this app's developer listing.
Its ignored PID and log files live under `.playwright-cli/garmin-browser/`.

Chrome currently rejects Playwright's standard `DOM.setFileInputFiles`
protocol when control comes through the extension. The upload helper avoids
the native Finder dialog by creating a browser `File`, assigning it through a
`DataTransfer`, dispatching the same input/change events as the chooser, and
then verifying the exact filename and byte size before submission:

```sh
npm run garmin:browser-upload
npm run garmin:browser-upload -- --submit
```

The generated browser script contains the package bytes only under the
gitignored `.playwright-cli/garmin-browser/` directory.

The authenticated builder copies `app/` to a private temporary directory,
injects the refresh token and selected baby only into that copy, builds into
the gitignored `output/e2e/` directory, and removes the temporary source tree.
No tracked resource contains credentials.

## Toolcraft

The Toolcraft CLI and MCP server expose `screenshot`, `press`, `tap`, and
`swipe`. Each command creates and closes its own Garmin session, so it does not
leak a long-running `monkeydo` process.

```sh
node tools/garmin-pilot/dist/cli.js screenshot \
  --device fenix7 \
  --prg output/e2e/BabyDaybook-auth-fenix7.prg \
  --path output/e2e/device.png \
  --region device

node tools/garmin-pilot/dist/cli.js mcp
```

For multi-step flows, use the JavaScript SDK so one loaded session retains app
state between actions. Toolcraft's one-command lifecycle is deliberately
stateless and is best for agent operations and individual captures/actions.
