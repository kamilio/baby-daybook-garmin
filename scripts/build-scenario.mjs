#!/usr/bin/env node
import { execFile } from "node:child_process";
import { cp, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join, resolve } from "node:path";
import { promisify } from "node:util";

const exec = promisify(execFile);
const root = resolve(import.meta.dirname, "..");
const scenario = process.argv[2] || "home";
const device = process.argv[3] || "fenix7";
const allowed = new Set([
  "home",
  "home-unconfigured",
  "bottle-type",
  "bottle-type-formula",
  "bottle-amount",
  "bottle-amount-min",
  "bottle-amount-max",
  "bottle-success",
  "wet-dirty-success",
  "sleep-inactive",
  "sleep-active",
  "sleep-start-success",
  "sleep-stop-success",
  "sleep-conflict-running",
  "event-log",
  "glance-profile",
]);
if (!allowed.has(scenario)) throw new Error(`Unknown scenario ${JSON.stringify(scenario)}; expected ${[...allowed].join(", ")}`);

const temp = await mkdtemp(join(tmpdir(), "baby-daybook-scenario-"));
const app = join(temp, "app");
try {
  await cp(join(root, "app"), app, { recursive: true, filter: source => basename(source) !== "bin" });
  await writeFile(
    join(app, "source-e2e/ScenarioConfig.mc"),
    `module ScenarioConfig {\n    const NAME = ${JSON.stringify(scenario)};\n}\n`,
  );
  const outputDir = join(root, "output/e2e/scenarios");
  await mkdir(outputDir, { recursive: true });
  const output = join(outputDir, `${scenario}-${device}.prg`);
  const key = join(root, "keys/developer_key.der");
  const result = await exec("monkeyc", ["-d", device, "-f", "monkey-e2e.jungle", "-o", output, "-y", key], {
    cwd: app,
    maxBuffer: 16_000_000,
  });
  process.stdout.write(result.stdout);
  process.stdout.write(`${output}\n`);
} finally {
  await rm(temp, { recursive: true, force: true });
}
