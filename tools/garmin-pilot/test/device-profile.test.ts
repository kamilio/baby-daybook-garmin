import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { loadDeviceProfile } from "../src/device-profile.js";

const created: string[] = [];
afterEach(async () => Promise.all(created.splice(0).map(path => rm(path, { recursive: true, force: true }))));

describe("loadDeviceProfile", () => {
  it("loads display and key geometry from Garmin simulator metadata", async () => {
    const root = await mkdtemp(join(tmpdir(), "garmin-profile-test-"));
    created.push(root);
    const directory = join(root, "testwatch");
    await mkdir(directory);
    const png = Buffer.alloc(24);
    png.set(Buffer.from([0x89, 0x50, 0x4e, 0x47]), 0);
    png.writeUInt32BE(400, 16);
    png.writeUInt32BE(600, 20);
    await writeFile(join(directory, "watch.png"), png);
    await writeFile(join(directory, "simulator.json"), JSON.stringify({
      image: "watch.png",
      display: { isTouch: true, shape: "round", location: { x: 50, y: 100, width: 300, height: 300 } },
      keys: [{ id: "enter", behavior: "onSelect", location: { x: 360, y: 120, width: 40, height: 60 } }],
    }));

    const profile = await loadDeviceProfile("testwatch", root);
    expect(profile.imageWidth).toBe(400);
    expect(profile.imageHeight).toBe(600);
    expect(profile.display).toMatchObject({ width: 300, height: 300, isTouch: true, shape: "round" });
    expect(profile.keys[0]).toMatchObject({ id: "enter", behavior: "onSelect" });
  });
});
