#!/usr/bin/env node

import { access, mkdir, readFile, writeFile } from "node:fs/promises";
import { constants } from "node:fs";
import { homedir } from "node:os";
import { basename, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import process from "node:process";

const DEFAULT_FILE = "app/bin/BabyDaybook-beta.iq";
const DEFAULT_VERSION = "0.16.0-beta.1";
const DEFAULT_SESSION = "garmin-developer";
const DEFAULT_CLI = resolve(homedir(), ".codex/skills/playwright/scripts/playwright_cli.sh");
const GENERATED_SCRIPT = resolve(".playwright-cli/garmin-browser/inject-upload.js");

function parseArgs(argv) {
  const options = { file: DEFAULT_FILE, version: DEFAULT_VERSION, session: DEFAULT_SESSION, submit: false };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--submit") options.submit = true;
    else if (["--file", "--version", "--session"].includes(arg)) {
      const value = argv[index + 1];
      if (!value) throw new Error(`${arg} needs a value`);
      options[arg.slice(2)] = value;
      index += 1;
    } else if (arg === "--help" || arg === "-h") {
      console.log(`Usage: npm run garmin:browser-upload -- [options]

Inject an IQ package into Garmin's upload form through page JavaScript. This
avoids Chrome's blocked DOM.setFileInputFiles protocol and the native chooser.

Options:
  --file PATH       IQ package (default: ${DEFAULT_FILE})
  --version VALUE   App version (default: ${DEFAULT_VERSION})
  --session NAME    Attached Playwright CLI session (default: ${DEFAULT_SESSION})
  --submit          Click Upload and publish after validation`);
      return null;
    } else throw new Error(`Unknown argument: ${arg}`);
  }
  return options;
}

function runCli(cliPath, session, args) {
  const result = spawnSync("bash", [cliPath, `--session=${session}`, ...args], {
    encoding: "utf8",
    timeout: 60_000,
    maxBuffer: 4_000_000,
  });
  if (result.status !== 0) {
    throw new Error(result.stdout.trim() || result.stderr.trim() || "Playwright CLI command failed");
  }
  return result.stdout;
}

function browserScript({ bytes, name, version, submit }) {
  const payload = {
    base64: bytes.toString("base64"),
    name,
    type: "application/octet-stream",
  };
  return `async (page) => {
  const input = page.locator('input[type="file"]').first();
  await input.waitFor({ state: "attached", timeout: 10000 });
  await input.evaluate((element, payload) => {
    const binary = atob(payload.base64);
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
    const transfer = new DataTransfer();
    transfer.items.add(new File([bytes], payload.name, { type: payload.type }));
    element.files = transfer.files;
    element.dispatchEvent(new Event("input", { bubbles: true, composed: true }));
    element.dispatchEvent(new Event("change", { bubbles: true, composed: true }));
  }, ${JSON.stringify(payload)});
  const version = page.getByRole("textbox", { name: /App Version/i });
  await version.fill(${JSON.stringify(version)});
  const selected = await input.evaluate((element) => ({
    name: element.files?.[0]?.name || "",
    size: element.files?.[0]?.size || 0,
  }));
  if (selected.name !== ${JSON.stringify(name)} || selected.size !== ${bytes.length}) {
    throw new Error("Garmin file input did not retain the injected IQ package");
  }
  const upload = page.getByRole("button", { name: /Upload and publish/i });
  await upload.waitFor({ state: "visible", timeout: 10000 });
  await page.waitForFunction(() => {
    const button = [...document.querySelectorAll("button")].find((item) => /Upload and publish/i.test(item.textContent || ""));
    return button && !button.disabled;
  }, null, { timeout: 10000 });
  ${submit ? "await upload.click();" : ""}
}`;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (!options) return;
  const file = resolve(options.file);
  if (!file.endsWith(".iq")) throw new Error("--file must point to an .iq package");
  await access(file, constants.R_OK);
  const bytes = await readFile(file);
  const cliPath = process.env.GARMIN_PLAYWRIGHT_CLI || DEFAULT_CLI;
  await access(cliPath, constants.R_OK);
  await mkdir(resolve(GENERATED_SCRIPT, ".."), { recursive: true });
  await writeFile(GENERATED_SCRIPT, browserScript({
    bytes,
    name: basename(file),
    version: options.version,
    submit: options.submit,
  }));
  runCli(cliPath, options.session, ["run-code", "--filename", GENERATED_SCRIPT]);
  console.log(`${basename(file)} injected into normal Chrome as version ${options.version}.`);
  console.log(options.submit ? "Upload submitted to Garmin." : "Upload form is ready; rerun with --submit to publish.");
}

main().catch((error) => {
  console.error(`Error: ${error.message}`);
  process.exitCode = 1;
});
