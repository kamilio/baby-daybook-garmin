import { execFile } from "node:child_process";
import { mkdir, realpath } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { promisify } from "node:util";
import { GarminPilot } from "../tools/garmin-pilot/dist/index.js";

const exec = promisify(execFile);
const root = resolve(import.meta.dirname, "..");
const output = resolve(root, "output/e2e/input");
await mkdir(output, { recursive: true });

const { stdout: monkeycCommand } = await exec("/usr/bin/which", ["monkeyc"]);
const monkeyc = await realpath(monkeycCommand.trim());
const sdk = resolve(dirname(monkeyc), "..");
const sample = resolve(sdk, "samples/Input");
const prg = resolve(output, "GarminInput-fenix7.prg");
await exec(monkeyc, ["-d", "fenix7", "-f", "monkey.jungle", "-o", prg, "-y", resolve(root, "keys/developer_key.der")], {
  cwd: sample,
  maxBuffer: 16 * 1024 * 1024,
});

const pilot = await GarminPilot.launch();
try {
  const watch = await pilot.newSession({ device: "fenix7", prg });
  await watch.waitForQuiet(750);
  let state = await watch.screenshot({ path: resolve(output, "initial.png"), region: "device" });

  await watch.press("Down", { settleMs: 200 });
  state = await watch.waitForScreenshotChange(state.path, { outputPath: resolve(output, "down.png") });

  await watch.tap({ x: 0.5, y: 0.5 }, { settleMs: 200 });
  state = await watch.waitForScreenshotChange(state.path, { outputPath: resolve(output, "tap.png") });

  const screenshots = ["initial.png", "down.png", "tap.png"];
  // macOS can synthesize a drag, but the Connect IQ Simulator does not expose
  // a supported input API and inconsistently recognizes those drags. Keep it
  // available for diagnostics without making it an acceptance gate.
  if (process.env.GARMIN_PILOT_TEST_SWIPE === "1") {
    await watch.swipe({ x: 0.5, y: 0.9 }, { x: 0.5, y: 0.1 }, { durationMs: 50, settleMs: 200 });
    state = await watch.waitForScreenshotChange(state.path, { outputPath: resolve(output, "swipe.png") });
    screenshots.push("swipe.png");
  }

  await watch.assertNoNewCrash();
  process.stdout.write(`${JSON.stringify({
    ok: true,
    device: watch.device,
    verified: ["physical-button", "touch-tap"],
    swipe: process.env.GARMIN_PILOT_TEST_SWIPE === "1" ? "verified" : "experimental-not-run",
    screenshots: screenshots.map(name => resolve(output, name)),
  })}\n`);
} finally {
  pilot.close();
}
