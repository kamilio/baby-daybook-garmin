#!/usr/bin/env node

import { access, mkdir } from "node:fs/promises";
import { constants } from "node:fs";
import { homedir } from "node:os";
import { resolve } from "node:path";
import { createInterface } from "node:readline/promises";
import process from "node:process";
import { chromium } from "playwright-core";

const DEFAULT_APP_ID = "d319a3ff-9e5d-4a1d-bb79-2674276e1ac9";
const DEFAULT_PROFILE = resolve(
  homedir(),
  ".config/baby-daybook-garmin/garmin-developer-profile",
);

function usage() {
  console.log(`Usage:
  npm run garmin:login
  npm run garmin:publish -- --version VERSION --notes TEXT [options]

Options:
  --file PATH       IQ package (default: app/bin/BabyDaybook-beta.iq)
  --version VALUE   Connect IQ Store version, e.g. 0.3.0-beta.1
  --notes TEXT      English release notes
  --dry-run         Validate and print the plan without opening a browser
  --login           Open Garmin Developer and save an authenticated profile
  --headless        Run without a visible browser (not recommended initially)
  --help            Show this help

Environment:
  GARMIN_PUBLISH_PROFILE  Chrome profile directory (default: ${DEFAULT_PROFILE})
  GARMIN_APP_ID           Store listing UUID (default: ${DEFAULT_APP_ID})`);
}

function parseArgs(argv) {
  const result = {
    file: "app/bin/BabyDaybook-beta.iq",
    version: "",
    notes: "",
    dryRun: false,
    login: false,
    headless: false,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--dry-run") result.dryRun = true;
    else if (arg === "--login") result.login = true;
    else if (arg === "--headless") result.headless = true;
    else if (arg === "--help" || arg === "-h") result.help = true;
    else if (["--file", "--version", "--notes"].includes(arg)) {
      const value = argv[index + 1];
      if (!value || value.startsWith("--")) throw new Error(`${arg} needs a value`);
      result[arg.slice(2)] = value;
      index += 1;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return result;
}

async function validate(options) {
  if (options.login) return;
  if (!options.version) throw new Error("--version is required");
  if (options.version.length > 20) throw new Error("--version must be at most 20 characters");
  if (!options.notes.trim()) throw new Error("--notes is required");
  options.file = resolve(options.file);
  if (!options.file.endsWith(".iq")) throw new Error("--file must point to an .iq package");
  await access(options.file, constants.R_OK);
}

async function openContext(profile, headless) {
  await mkdir(profile, { recursive: true });
  return chromium.launchPersistentContext(profile, {
    channel: "chrome",
    headless,
    viewport: { width: 1440, height: 1000 },
  });
}

async function login(profile) {
  const context = await openContext(profile, false);
  const page = context.pages()[0] ?? await context.newPage();
  await page.goto("https://apps-developer.garmin.com/", { waitUntil: "domcontentloaded" });
  console.log(`Chrome is open. Sign in to Garmin, then return here.`);
  const prompt = createInterface({ input: process.stdin, output: process.stdout });
  await prompt.question("Press Enter after the developer dashboard is visible: ");
  prompt.close();
  await context.close();
  console.log(`Saved the authenticated browser profile in ${profile}`);
}

async function visible(locator, timeout = 500) {
  try {
    await locator.first().waitFor({ state: "visible", timeout });
    return true;
  } catch {
    return false;
  }
}

async function publish(options, profile, appId) {
  const context = await openContext(profile, options.headless);
  const page = context.pages()[0] ?? await context.newPage();
  const listingUrl = `https://apps-developer.garmin.com/apps/${appId}`;

  try {
    console.log(`Opening ${listingUrl}`);
    await page.goto(listingUrl, { waitUntil: "domcontentloaded" });

    const uploadButton = page.getByRole("button", { name: "Upload New Version" });
    if (!await visible(uploadButton, 10_000)) {
      throw new Error("Garmin login is missing or expired. Run: npm run garmin:login");
    }
    await uploadButton.click();

    const fileInput = page.locator('input[type="file"]');
    await fileInput.setInputFiles(options.file);
    await page.getByRole("textbox", { name: /App Version/i }).fill(options.version);

    const uploadAndPublish = page.getByRole("button", { name: /Upload and publish/i });
    await uploadAndPublish.waitFor({ state: "visible", timeout: 10_000 });
    await uploadAndPublish.click();
    console.log("Package uploaded; waiting for Garmin validation…");

    const deadline = Date.now() + 5 * 60_000;
    let notesFilled = false;
    while (Date.now() < deadline) {
      const versionOnListing = page.getByText(`Version ${options.version}`, { exact: true });
      if (await visible(versionOnListing)) {
        console.log(`Published Garmin beta ${options.version}`);
        return;
      }

      const notesField = page.getByRole("textbox", { name: /what.?s new|release notes/i })
        .or(page.locator("textarea").first());
      if (!notesFilled && await visible(notesField)) {
        await notesField.first().fill(options.notes);
        notesFilled = true;
      }

      if (notesFilled) {
        const publishButton = page.getByRole("button", { name: /publish|submit/i })
          .filter({ hasNotText: /upload/i });
        if (await visible(publishButton)) {
          await publishButton.first().click();
        }
      }

      const error = page.getByRole("alert").filter({ hasText: /error|failed|invalid/i });
      if (await visible(error)) throw new Error((await error.first().innerText()).trim());
      await page.waitForTimeout(1_000);
    }
    throw new Error("Timed out waiting for Garmin validation/publishing (5 minutes)");
  } catch (error) {
    await mkdir("output/playwright", { recursive: true });
    await page.screenshot({ path: "output/playwright/garmin-publish-error.png", fullPage: true });
    throw error;
  } finally {
    await context.close();
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    usage();
    return;
  }
  await validate(options);

  const profile = resolve(process.env.GARMIN_PUBLISH_PROFILE || DEFAULT_PROFILE);
  const appId = process.env.GARMIN_APP_ID || DEFAULT_APP_ID;
  if (options.login) {
    await login(profile);
    return;
  }

  console.log(`Garmin beta publish plan:
  file:    ${options.file}
  version: ${options.version}
  notes:   ${options.notes}
  app:     ${appId}
  profile: ${profile}`);
  if (options.dryRun) {
    console.log("Dry run complete; Garmin was not contacted.");
    return;
  }
  await publish(options, profile, appId);
}

main().catch((error) => {
  console.error(`Error: ${error.message}`);
  process.exitCode = 1;
});
