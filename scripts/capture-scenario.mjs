#!/usr/bin/env node
import { execFile } from "node:child_process";
import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";
import { promisify } from "node:util";
import { GarminPilot } from "../tools/garmin-pilot/dist/index.js";

const exec = promisify(execFile);
const root = resolve(import.meta.dirname, "..");
const scenario = process.argv[2] || "home";
const device = process.argv[3] || "fenix7";
await exec(process.execPath, [resolve(root, "scripts/build-scenario.mjs"), scenario, device], { cwd: root, maxBuffer: 16_000_000 });

const outputDir = resolve(root, "output/e2e/scenarios", scenario);
await mkdir(outputDir, { recursive: true });
const pilot = await GarminPilot.launch();
try {
  const options = { device, prg: resolve(root, `output/e2e/scenarios/${scenario}-${device}.prg`), launchTimeout: 30_000 };
  let watch;
  try {
    watch = await pilot.newSession(options);
  } catch (firstError) {
    // Garmin's one simulator socket can remain wedged after many sequential
    // monkeydo sessions. A clean restart recovers without mouse input.
    await pilot.restartSimulator();
    watch = await pilot.newSession(options).catch((retryError) => {
      retryError.cause = firstError;
      throw retryError;
    });
  }
  await watch.waitForQuiet(500);
  const capture = await watch.screenshot({ path: resolve(outputDir, `${device}.png`), region: "device" });
  await watch.assertNoNewCrash();
  process.stdout.write(`${JSON.stringify({ ok: true, scenario, device, screenshot: capture.path })}\n`);
} finally {
  pilot.close();
}
