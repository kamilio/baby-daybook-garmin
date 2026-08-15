#!/usr/bin/env node
import { execFile } from "node:child_process";
import { resolve } from "node:path";
import { promisify } from "node:util";

const exec = promisify(execFile);
const root = resolve(import.meta.dirname, "..");
const scenarios = process.argv.slice(2).length ? process.argv.slice(2) : [
  "home", "home-unconfigured", "bottle-type", "bottle-type-formula", "bottle-amount", "bottle-amount-min", "bottle-amount-max",
  "bottle-success", "wet-dirty-success", "sleep-inactive", "sleep-active", "sleep-start-success", "sleep-stop-success",
  "sleep-conflict-running", "event-log", "glance-profile",
];
const devices = ["fenix7", "fenix7s", "fenix7x"];

for (const scenario of scenarios) {
  for (const device of devices) {
    let result;
    try {
      result = await exec(process.execPath, [resolve(root, "scripts/capture-scenario.mjs"), scenario, device], {
        cwd: root,
        maxBuffer: 16_000_000,
      });
    } catch (firstError) {
      result = await exec(process.execPath, [resolve(root, "scripts/capture-scenario.mjs"), scenario, device], {
        cwd: root,
        maxBuffer: 16_000_000,
      }).catch((retryError) => {
        retryError.cause = firstError;
        throw retryError;
      });
    }
    process.stdout.write(result.stdout);
  }
}
