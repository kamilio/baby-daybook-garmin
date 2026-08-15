#!/usr/bin/env node
import { execFile } from "node:child_process";
import { cp, mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import { promisify } from "node:util";

const exec = promisify(execFile);
const root = resolve(import.meta.dirname, "..");
const device = process.argv[2] || "fenix7";
const babyName = process.argv[3] || "Victoria";
const authPath = join(homedir(), ".config/baby-daybook/auth.json");
const auth = JSON.parse(await readFile(authPath, "utf8"));
if (typeof auth.refreshToken !== "string" || !auth.refreshToken) throw new Error(`No refreshToken in ${authPath}`);

const cli = resolve(root, "../baby-daybook-sdk/dist/cli.js");
const { stdout } = await exec(process.execPath, [cli, "babies", "list", "--output", "json"], { maxBuffer: 4_000_000 });
const parsed = JSON.parse(stdout);
const babies = Array.isArray(parsed) ? parsed : parsed.data;
const baby = babies.find(item => item.name === babyName || item.displayName === babyName);
if (!baby?.uid) throw new Error(`Baby ${JSON.stringify(babyName)} was not found; available: ${babies.map(item => item.name).join(", ")}`);

const temp = await mkdtemp(join(tmpdir(), "garmin-pilot-auth-"));
const app = join(temp, "app");
try {
  await cp(join(root, "app"), app, { recursive: true, filter: source => basename(source) !== "bin" });
  const propertiesPath = join(app, "resources/properties.xml");
  let properties = await readFile(propertiesPath, "utf8");
  const escapeXml = value => value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
  properties = properties
    .replace('<property id="refreshToken" type="string"></property>', `<property id="refreshToken" type="string">${escapeXml(auth.refreshToken)}</property>`)
    .replace('<property id="babyUid" type="string"></property>', `<property id="babyUid" type="string">${escapeXml(baby.uid)}</property>`);
  await writeFile(propertiesPath, properties, { mode: 0o600 });

  const outputDir = join(root, "output/e2e");
  await mkdir(outputDir, { recursive: true });
  const output = join(outputDir, `BabyDaybook-auth-${device}.prg`);
  const key = join(root, "keys/developer_key.der");
  const result = await exec("monkeyc", ["-d", device, "-f", "monkey.jungle", "-o", output, "-y", key], { cwd: app, maxBuffer: 16_000_000 });
  process.stdout.write(result.stdout);
  process.stdout.write(`${output}\n`);
} finally {
  await rm(temp, { recursive: true, force: true });
}
