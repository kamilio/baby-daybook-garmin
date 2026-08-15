import { createHash } from "node:crypto";
import { readFile, unlink } from "node:fs/promises";
import { stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { resolve } from "node:path";
import { captureDevice, captureWindow, click, drag, findSimulatorWindow, type WindowInfo } from "./macos.js";
import { run } from "./process.js";
import type { DeviceKey, DeviceProfile, Rect } from "./device-profile.js";

export type GarminButton = "Light" | "Up" | "Down" | "Start" | "Back" | "Menu";
export type Point = { x: number; y: number };
export type ScreenshotOptions = { path: string; region?: "window" | "device" | "framebuffer" };
export type CrashLogSnapshot = { path: string; exists: boolean; size: number; mtimeMs: number; hash?: string };

export async function snapshotCrashLog(): Promise<CrashLogSnapshot> {
  const path = join(tmpdir(), "com.garmin.connectiq/GARMIN/APPS/LOGS/CIQ_LOG.YML");
  try {
    const [metadata, content] = await Promise.all([stat(path), readFile(path)]);
    return { path, exists: true, size: metadata.size, mtimeMs: metadata.mtimeMs, hash: createHash("sha256").update(content).digest("hex") };
  } catch {
    return { path, exists: false, size: 0, mtimeMs: 0 };
  }
}

const BUTTON_IDS: Record<GarminButton, string> = { Light: "power", Up: "up", Down: "down", Start: "enter", Back: "esc", Menu: "menu" };

export class GarminSession {
  constructor(
    readonly device: string,
    private windowInfo: WindowInfo,
    readonly prg?: string,
    private loaderPid?: number,
    readonly crashBaseline?: CrashLogSnapshot,
    readonly profile?: DeviceProfile,
  ) {}

  get window() { return { ...this.windowInfo }; }

  async refreshWindow() {
    const next = await findSimulatorWindow();
    if (!next) throw new Error("Connect IQ Simulator window disappeared");
    this.windowInfo = next;
    return this.window;
  }

  private imageMetrics() {
    if (!this.profile) throw new Error(`No simulator profile loaded for ${this.device}`);
    const scale = this.windowInfo.width / this.profile.imageWidth;
    const renderedHeight = this.profile.imageHeight * scale;
    return { scale, top: (this.windowInfo.height - renderedHeight) / 2 };
  }

  private profileRectCenter(rect: Rect): Point {
    const { scale, top } = this.imageMetrics();
    return {
      x: this.windowInfo.x + (rect.x + rect.width / 2) * scale,
      y: this.windowInfo.y + top + (rect.y + rect.height / 2) * scale,
    };
  }

  private keyFor(button: GarminButton): DeviceKey {
    const id = BUTTON_IDS[button];
    const key = this.profile?.keys.find(item => item.id === id);
    if (!key) throw new Error(`${button} is not exposed by the ${this.device} simulator profile`);
    return key;
  }

  private screenPoint(point: Point): Point {
    if (point.x < 0 || point.x > 1 || point.y < 0 || point.y > 1) {
      throw new Error("Touch coordinates must be normalized from 0 to 1");
    }
    const display = this.profile?.display;
    if (!display) throw new Error(`No display geometry loaded for ${this.device}`);
    const { scale, top } = this.imageMetrics();
    return {
      x: this.windowInfo.x + (display.x + point.x * display.width) * scale,
      y: this.windowInfo.y + top + (display.y + point.y * display.height) * scale,
    };
  }

  async press(button: GarminButton, options: { holdMs?: number; settleMs?: number } = {}) {
    await this.refreshWindow();
    const key = this.keyFor(button);
    const holdMs = key.isHold ? (options.holdMs ?? 800) : (options.holdMs ?? 0);
    const target = this.profileRectCenter(key.location);
    await click(target.x, target.y, holdMs);
    await this.waitForQuiet(options.settleMs ?? 150);
  }

  async tap(point: Point, options: { settleMs?: number } = {}) {
    await this.refreshWindow();
    const target = this.screenPoint(point);
    await click(target.x, target.y);
    await this.waitForQuiet(options.settleMs ?? 150);
  }

  async swipe(from: Point, to: Point, options: { durationMs?: number; settleMs?: number } = {}) {
    await this.refreshWindow();
    await drag(this.screenPoint(from), this.screenPoint(to), options.durationMs ?? 250);
    await this.waitForQuiet(options.settleMs ?? 150);
  }

  async screenshot(options: ScreenshotOptions) {
    await this.refreshWindow();
    const path = resolve(options.path);
    const region = options.region ?? "window";
    if (region === "window") {
      await captureWindow(this.windowInfo.id, path);
    } else if (region === "framebuffer") {
      // Use Garmin's native capture command. This returns the exact device
      // framebuffer, but its modal dialog requires uninterrupted GUI focus.
      await unlink(path).catch(() => undefined);
      await captureDevice(path);
    } else {
      // A deterministic, non-modal crop around the physical display. This is
      // ideal for E2E assertions even when a person is sharing the desktop.
      const whole = `${path}.window.png`;
      const cropped = `${path}.crop.png`;
      await captureWindow(this.windowInfo.id, whole);
      try {
        const { stdout } = await run("/usr/bin/sips", ["-g", "pixelWidth", "-g", "pixelHeight", whole]);
        const width = Number(stdout.match(/pixelWidth: (\d+)/)?.[1]);
        const height = Number(stdout.match(/pixelHeight: (\d+)/)?.[1]);
        if (!width || !height) throw new Error("Could not read captured simulator dimensions");
        if (!this.profile) throw new Error(`No display geometry loaded for ${this.device}`);
        const scale = width / this.profile.imageWidth;
        const imageHeight = this.profile.imageHeight * scale;
        const top = (height - imageHeight) / 2;
        const display = this.profile.display;
        const cropWidth = Math.round(display.width * scale);
        const cropHeight = Math.round(display.height * scale);
        const offsetX = Math.round(display.x * scale);
        const offsetY = Math.round(top + display.y * scale);
        await run("/usr/bin/sips", ["-c", String(cropHeight), String(cropWidth), "--cropOffset", String(offsetY), String(offsetX), whole, "--out", cropped]);
        // Simulator zoom is user-configurable and can reset when its socket is
        // restarted. Normalize to the profile's 2x display dimensions so
        // visual baselines are stable across zoom levels and restarts.
        await run("/usr/bin/sips", ["-z", String(display.height * 2), String(display.width * 2), cropped, "--out", path]);
      } finally {
        await unlink(whole).catch(() => undefined);
        await unlink(cropped).catch(() => undefined);
      }
    }
    return { path, window: this.window };
  }

  async screenshotHash(path: string) {
    return createHash("sha256").update(await readFile(path)).digest("hex");
  }

  async waitForScreenshotChange(previousPath: string, options: { timeout?: number; pollMs?: number; outputPath?: string; region?: ScreenshotOptions["region"] } = {}) {
    const previous = await this.screenshotHash(previousPath);
    const timeout = options.timeout ?? 5_000;
    const pollMs = options.pollMs ?? 100;
    const outputPath = resolve(options.outputPath ?? `${previousPath}.next.png`);
    const deadline = Date.now() + timeout;
    do {
      await this.screenshot({ path: outputPath, region: options.region ?? "device" });
      if (await this.screenshotHash(outputPath) !== previous) return { path: outputPath };
      await this.waitForQuiet(pollMs);
    } while (Date.now() < deadline);
    throw new Error(`Simulator screenshot did not change within ${timeout}ms`);
  }

  async waitForQuiet(ms = 150) { await new Promise(resolve => setTimeout(resolve, ms)); }

  async assertNoNewCrash() {
    const current = await snapshotCrashLog();
    const baseline = this.crashBaseline;
    const changed = current.exists && (!baseline?.exists || current.hash !== baseline.hash || current.mtimeMs > baseline.mtimeMs);
    if (changed) throw new Error(`Connect IQ crash log changed during the session: ${current.path}`);
    return { ok: true, crashLog: current.path };
  }

  async killApp() {
    await run("/usr/bin/osascript", ["-e", 'tell application "System Events" to tell process "simulator" to click menu item "Kill App" of menu "File" of menu bar 1']);
  }

  close() {
    if (this.loaderPid) {
      try { process.kill(-this.loaderPid, "SIGINT"); } catch {}
      this.loaderPid = undefined;
    }
  }
}
