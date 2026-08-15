#!/usr/bin/env node
import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { resolve } from "node:path";
import { promisify } from "node:util";

const exec = promisify(execFile);
const root = resolve(import.meta.dirname, "..");
const auth = JSON.parse(await readFile(resolve(homedir(), ".config/baby-daybook/auth.json"), "utf8"));
const cli = resolve(root, "../baby-daybook-sdk/dist/cli.js");
const { stdout } = await exec(process.execPath, [cli, "babies", "list", "--output", "json"], { maxBuffer: 4_000_000 });
const parsed = JSON.parse(stdout);
const babies = Array.isArray(parsed) ? parsed : parsed.data;
const babyName = process.argv[2] || "Victoria";
const baby = babies.find(item => item.name === babyName || item.displayName === babyName);
if (!baby?.uid) throw new Error(`Baby ${JSON.stringify(babyName)} was not found`);

const response = await fetch("https://baby-daybook-kjopek.fly.dev/garmin/sync", {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ refreshToken: auth.refreshToken, babyUid: baby.uid, events: [] }),
});
const body = await response.json();
if (!response.ok || body.ok !== true || !Array.isArray(body.bottleGroups) || !("activeSleep" in body) ||
    typeof body.baby?.name !== "string" || !Number.isSafeInteger(body.baby?.birthdayMillis)) {
  throw new Error(`Relay verification failed with HTTP ${response.status}`);
}
process.stdout.write(`${JSON.stringify({
  ok: true,
  bottleGroups: body.bottleGroups.map(group => ({ title: group.title, messageKey: group.messageKey })),
  activeSleep: body.activeSleep !== null,
  baby: { name: body.baby.name, hasBirthday: true },
  acknowledged: body.acked.length,
})}\n`);
