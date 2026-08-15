import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";
import { GarminPilot } from "../tools/garmin-pilot/dist/index.js";

const root = resolve(import.meta.dirname, "..");
const prg = resolve(root, process.argv[2] || "output/e2e/BabyDaybook-auth-fenix7.prg");
const device = process.argv[3] || "fenix7";
const output = resolve(root, "output/e2e/background");
await mkdir(output, { recursive: true });

const pilot = await GarminPilot.launch();
try {
  const watch = await pilot.newSession({ device, prg });
  await watch.waitForQuiet(750);
  const window = await watch.screenshot({ path: `${output}/window.png`, region: "window" });
  const deviceCapture = await watch.screenshot({ path: `${output}/device.png`, region: "device" });
  await watch.assertNoNewCrash();
  process.stdout.write(`${JSON.stringify({ ok: true, device, window: window.path, deviceCapture: deviceCapture.path })}\n`);
} finally {
  pilot.close();
}
