import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";
import { GarminPilot } from "../tools/garmin-pilot/dist/index.js";

const root = resolve(import.meta.dirname, "..");
const prg = resolve(root, process.argv[2] || "output/e2e/BabyDaybook-auth-fenix7.prg");
const output = resolve(root, "output/e2e/smoke");
await mkdir(output, { recursive: true });

const pilot = await GarminPilot.launch();
try {
  const watch = await pilot.newSession({ device: process.argv[3] || "fenix7", prg });
  await watch.waitForQuiet(750);
  const home = await watch.screenshot({ path: `${output}/home-window.png` });
  await watch.screenshot({ path: `${output}/home-device.png`, region: "device" });
  await watch.press("Down", { settleMs: 250 });
  const changed = await watch.waitForScreenshotChange(home.path, { outputPath: `${output}/down-window.png` });
  await watch.assertNoNewCrash();
  process.stdout.write(`${JSON.stringify({ ok: true, device: watch.device, home: home.path, changed: changed.path })}\n`);
} finally {
  pilot.close();
}
