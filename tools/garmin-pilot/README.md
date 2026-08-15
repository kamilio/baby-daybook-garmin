# garmin-pilot

Playwright/terminal-pilot-style automation for the macOS Garmin Connect IQ Simulator.

```ts
import { GarminPilot } from "garmin-pilot";

const pilot = await GarminPilot.launch();
const watch = await pilot.newSession({ device: "fenix7", prg: "app/bin/BabyDaybook-fenix7.prg" });

await watch.screenshot({ path: "output/home.png" });
await watch.screenshot({ path: "output/device.png", region: "device" });
await watch.screenshot({ path: "output/framebuffer.png", region: "framebuffer" });
await watch.press("Down");
await watch.press("Start");
await watch.tap({ x: 0.5, y: 0.7 });
// Experimental only: Garmin has no supported simulator input endpoint.
await watch.swipe({ x: 0.5, y: 0.8 }, { x: 0.5, y: 0.2 });
await watch.waitForScreenshotChange("output/home.png", { outputPath: "output/changed.png" });
await watch.assertNoNewCrash();
pilot.close();
```

Requirements: macOS, Connect IQ SDK tools on `PATH`, `brew install cliclick`, and Accessibility plus Screen Recording permission for the host terminal/Codex app.

The Toolcraft-backed CLI and MCP server expose screenshot, press, and tap:

```sh
npm run build
./dist/cli.js --help
./dist/cli.js mcp
```

Input is intentionally normalized. Touch coordinates range from `(0,0)` at the display's upper-left to `(1,1)` at its lower-right. Physical input uses Garmin behavior names (`Up`, `Down`, `Start`, `Back`, `Menu`, `Light`) rather than model-specific labels.

Screenshot regions are `window` (complete simulator window), `device` (deterministic display-area crop), and `framebuffer` (Garmin's exact 260×260 Fenix 7 export). `framebuffer` uses Garmin's modal Save dialog and therefore requires uninterrupted simulator focus while it runs; use `window` or `device` for unattended assertions.

## Background versus interactive operation

`GarminPilot.launch()`, `newSession()`, `screenshot({ region: "window" | "device" })`, `waitForScreenshotChange()`, and `assertNoNewCrash()` do not request Accessibility permission or intentionally activate the simulator. They are suitable while the desktop is shared, although loading a different `.prg` naturally changes the simulator window.

`press()`, `tap()`, `swipe()`, `killApp()`, and `screenshot({ region: "framebuffer" })` drive Garmin's GUI. Garmin publishes no headless input endpoint, so these operations require Accessibility permission and temporarily focus the simulator. Synthesized drags are not consistently recognized; `swipe()` is diagnostic/experimental. Run GUI input when the desktop is idle, in a separate macOS login session, or in a VM.

For this repository:

```sh
npm run e2e:auth-build   # local ignored binary; reads ~/.config/baby-daybook/auth.json
npm run e2e:background   # no input/focus changes
npm run e2e:scenario -- bottle-amount fenix7
npm run e2e:scenario-matrix
npm run e2e:smoke        # interactive Down-button smoke test
```

This repository's scenario build has its own manifest, UUID, and entry point.
It directly renders named production views from deterministic fixture state,
so visual acceptance tests do not depend on mouse input and scenario code is
not present in the release application.
