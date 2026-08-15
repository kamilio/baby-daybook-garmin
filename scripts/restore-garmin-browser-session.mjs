#!/usr/bin/env node

import { access, mkdir, open, readFile, unlink } from "node:fs/promises";
import { constants } from "node:fs";
import { homedir } from "node:os";
import { dirname, resolve } from "node:path";
import { spawn, spawnSync } from "node:child_process";
import process from "node:process";

const SESSION = process.env.GARMIN_BROWSER_SESSION || "garmin-developer";
const APP_ID = process.env.GARMIN_APP_ID || "d319a3ff-9e5d-4a1d-bb79-2674276e1ac9";
const LISTING_URL = `https://apps-developer.garmin.com/apps/${APP_ID}`;
const STATE_DIR = resolve(".playwright-cli/garmin-browser");
const PID_FILE = resolve(STATE_DIR, "attach.pid");
const LOG_FILE = resolve(STATE_DIR, "attach.log");
const DEFAULT_CLI = resolve(
  homedir(),
  ".codex/skills/playwright/scripts/playwright_cli.sh",
);

function usage() {
  console.log(`Usage:
  npm run garmin:browser          Restore the normal-Chrome CLI session
  npm run garmin:browser:status   Report whether it is attached

Environment:
  GARMIN_PLAYWRIGHT_CLI   playwright_cli.sh path
  GARMIN_BROWSER_SESSION session name (default: ${SESSION})
  GARMIN_APP_ID           Garmin developer listing UUID`);
}

function cli(args, options = {}) {
  return spawnSync("bash", [process.env.GARMIN_PLAYWRIGHT_CLI || DEFAULT_CLI, ...args], {
    encoding: "utf8",
    timeout: options.timeout ?? 15_000,
  });
}

function sessions() {
  const result = cli(["list", "--json"]);
  if (result.status !== 0) {
    throw new Error(result.stderr.trim() || result.stdout.trim() || "Could not list Playwright CLI sessions");
  }
  return JSON.parse(result.stdout).browsers || [];
}

function attachedSession() {
  return sessions().find((browser) => browser.name === SESSION && browser.status === "open");
}

async function removeStalePid() {
  try {
    const pid = Number((await readFile(PID_FILE, "utf8")).trim());
    if (Number.isInteger(pid) && pid > 0) {
      try {
        process.kill(pid, 0);
        return pid;
      } catch {
        // The previous background attach exited; replace its stale marker.
      }
    }
    await unlink(PID_FILE);
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  return null;
}

async function startBackgroundAttach() {
  const existingPid = await removeStalePid();
  if (existingPid) return existingPid;

  await mkdir(STATE_DIR, { recursive: true });
  const log = await open(LOG_FILE, "a");
  const child = spawn(
    "bash",
    [process.env.GARMIN_PLAYWRIGHT_CLI || DEFAULT_CLI, "attach", "--extension=chrome", `--session=${SESSION}`],
    { detached: true, stdio: ["ignore", log.fd, log.fd] },
  );
  child.unref();
  await writePid(PID_FILE, child.pid);
  await log.close();
  return child.pid;
}

async function writePid(path, pid) {
  const handle = await open(path, "w");
  try {
    await handle.writeFile(`${pid}\n`);
  } finally {
    await handle.close();
  }
}

async function waitForAttachment(timeoutMs = 12_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (attachedSession()) return true;
    await new Promise((resolveDelay) => setTimeout(resolveDelay, 500));
  }
  return false;
}

function navigate() {
  const result = cli([`--session=${SESSION}`, "goto", LISTING_URL], { timeout: 30_000 });
  if (result.status !== 0) {
    throw new Error(result.stderr.trim() || result.stdout.trim() || "Could not open the Garmin listing");
  }
}

async function main() {
  const args = new Set(process.argv.slice(2));
  if (args.has("--help") || args.has("-h")) return usage();
  await access(process.env.GARMIN_PLAYWRIGHT_CLI || DEFAULT_CLI, constants.R_OK);

  if (args.has("--status")) {
    const attached = attachedSession();
    console.log(attached
      ? `Garmin browser CLI session '${SESSION}' is attached to normal Chrome.`
      : `Garmin browser CLI session '${SESSION}' is not attached.`);
    process.exitCode = attached ? 0 : 1;
    return;
  }

  if (!attachedSession()) {
    const pid = await startBackgroundAttach();
    console.log(`Restoring '${SESSION}' in the background (PID ${pid})…`);
    if (!await waitForAttachment()) {
      console.log("In normal Chrome, activate the Playwright extension once, then rerun this command.");
      console.log(`The restore process remains in the background; log: ${LOG_FILE}`);
      return;
    }
  }

  navigate();
  console.log(`Garmin developer is open in normal Chrome; CLI session: ${SESSION}`);
}

main().catch((error) => {
  console.error(`Error: ${error.message}`);
  process.exitCode = 1;
});
