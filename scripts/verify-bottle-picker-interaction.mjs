#!/usr/bin/env node
import { execFile } from "node:child_process";
import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";
import { promisify } from "node:util";
import { GarminPilot } from "../tools/garmin-pilot/dist/index.js";

const exec = promisify(execFile);
const root = resolve(import.meta.dirname, "..");
const output = resolve(root, "output/e2e/picker-interaction");
await mkdir(output, { recursive: true });
await exec(process.execPath, [resolve(root, "scripts/build-scenario.mjs"), "bottle-amount", "fenix7"], {
  cwd: root,
  maxBuffer: 16_000_000,
});

const pilot = await GarminPilot.launch();
try {
  const watch = await pilot.newSession({
    device: "fenix7",
    prg: resolve(root, "output/e2e/scenarios/bottle-amount-fenix7.prg"),
  });
  await watch.waitForQuiet(750);
  let state = await watch.screenshot({ path: resolve(output, "initial-4oz.png"), region: "device" });

  await watch.press("Up", { settleMs: 250 });
  state = await watch.waitForScreenshotChange(state.path, { outputPath: resolve(output, "up-4.5oz.png") });

  await watch.press("Down", { settleMs: 250 });
  state = await watch.waitForScreenshotChange(state.path, { outputPath: resolve(output, "down-4oz.png") });

  await watch.press("Start", { settleMs: 350 });
  await watch.waitForScreenshotChange(state.path, { outputPath: resolve(output, "start-saved.png") });
  await watch.assertNoNewCrash();
  process.stdout.write(`${JSON.stringify({
    ok: true,
    device: watch.device,
    verified: ["Up increments", "Down decrements", "Start saves"],
    output,
  })}\n`);
} finally {
  pilot.close();
}
