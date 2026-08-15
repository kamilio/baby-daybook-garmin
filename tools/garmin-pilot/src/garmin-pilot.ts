import { resolve } from "node:path";
import { basename, join } from "node:path";
import { spawn } from "node:child_process";
import { readFile, readdir, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { createHash } from "node:crypto";
import { findSimulatorWindow } from "./macos.js";
import { run } from "./process.js";
import { GarminSession, snapshotCrashLog } from "./garmin-session.js";
import { loadDeviceProfile } from "./device-profile.js";

export type NewSessionOptions = {
  device: string;
  prg: string;
  cwd?: string;
  launchTimeout?: number;
};

export type LaunchOptions = { launchTimeout?: number };

type MediaSnapshot = Map<string, { mtimeMs: number; size: number }>;

async function snapshotSimulatorMedia(directory: string): Promise<MediaSnapshot> {
  const snapshot: MediaSnapshot = new Map();
  for (const name of await readdir(directory).catch(() => [] as string[])) {
    const metadata = await stat(join(directory, name)).catch(() => null);
    if (metadata?.isFile()) snapshot.set(name, { mtimeMs: metadata.mtimeMs, size: metadata.size });
  }
  return snapshot;
}

function mediaChanged(before: MediaSnapshot, after: MediaSnapshot) {
  for (const [name, metadata] of after) {
    const previous = before.get(name);
    if (!previous || previous.mtimeMs !== metadata.mtimeMs || previous.size !== metadata.size) return true;
  }
  return false;
}

async function simulatorHasProgram(directory: string, expectedHash: string) {
  for (const name of await readdir(directory).catch(() => [] as string[])) {
    if (!name.toUpperCase().endsWith(".PRG")) continue;
    const content = await readFile(join(directory, name)).catch(() => null);
    if (content && createHash("sha256").update(content).digest("hex") === expectedHash) return true;
  }
  return false;
}

export class GarminPilot {
  private active = new Set<GarminSession>();

  static async launch(options: LaunchOptions = {}) {
    if (process.platform !== "darwin") throw new Error("Garmin Pilot currently supports macOS only");
    if (!await findSimulatorWindow()) {
      await run("connectiq", [], { timeout: 5_000 }).catch(() => undefined);
      const deadline = Date.now() + (options.launchTimeout ?? 15_000);
      while (!await findSimulatorWindow()) {
        if (Date.now() >= deadline) throw new Error("Connect IQ Simulator did not open within 15 seconds");
        await new Promise(resolve => setTimeout(resolve, 250));
      }
    }
    return new GarminPilot();
  }

  async newSession(options: NewSessionOptions) {
    const cwd = options.cwd ? resolve(options.cwd) : process.cwd();
    const prg = resolve(cwd, options.prg);
    const crashBaseline = await snapshotCrashLog();
    const profile = await loadDeviceProfile(options.device);
    const mediaDirectory = join(tmpdir(), "com.garmin.connectiq/GARMIN/APPS/MEDIA");
    // The simulator retains the filename from the first PRG installed for an
    // application UUID. A later build can therefore update a different file
    // than basename(prg), especially while switching device profiles.
    const mediaBefore = await snapshotSimulatorMedia(mediaDirectory);
    const requestedHash = createHash("sha256").update(await readFile(prg)).digest("hex");
    // monkeydo stays attached for the lifetime of the loaded app, so it must
    // not be awaited like an ordinary command.
    const loader = spawn("monkeydo", [prg, options.device], { cwd, detached: true, stdio: "ignore" });
    loader.unref();
    const deadline = Date.now() + (options.launchTimeout ?? 15_000);
    let window = await findSimulatorWindow();
    let mediaAfter = await snapshotSimulatorMedia(mediaDirectory);
    let requestedProgramInstalled = await simulatorHasProgram(mediaDirectory, requestedHash);
    const isRequestedDeviceLoaded = () => {
      if (!window || !window.title.startsWith("CIQ Simulator -")) return false;
      // Loaded simulator windows contain the profile image plus roughly equal
      // title/status chrome above and below. Comparing aspect ratios supports
      // Retina and simulator zoom without hard-coding one window size.
      const renderedImageHeight = window.height - 56;
      if (renderedImageHeight <= 0) return false;
      return Math.abs((window.width / renderedImageHeight) - (profile.imageWidth / profile.imageHeight)) < 0.02;
    };
    const isProgramPushed = () => mediaChanged(mediaBefore, mediaAfter) || requestedProgramInstalled;
    while ((!isRequestedDeviceLoaded() || !isProgramPushed()) && Date.now() < deadline) {
      await new Promise(resolve => setTimeout(resolve, 200));
      window = await findSimulatorWindow();
      mediaAfter = await snapshotSimulatorMedia(mediaDirectory);
      requestedProgramInstalled = await simulatorHasProgram(mediaDirectory, requestedHash);
    }
    if (!window || !isRequestedDeviceLoaded() || !isProgramPushed()) {
      try { if (loader.pid) process.kill(-loader.pid, "SIGINT"); } catch {}
      throw new Error(`Connect IQ Simulator did not load ${basename(prg)} for ${options.device} within ${options.launchTimeout ?? 15_000}ms`);
    }
    // Give the VM one render cycle even when the simulator was already on the
    // requested device and the window title did not need to change.
    await new Promise(resolve => setTimeout(resolve, 500));
    const session = new GarminSession(options.device, window, prg, loader.pid, crashBaseline, profile);
    this.active.add(session);
    return session;
  }

  sessions() { return [...this.active]; }

  async restartSimulator(launchTimeout = 15_000) {
    this.close();
    const existing = await findSimulatorWindow();
    if (existing) {
      try { process.kill(existing.pid, "SIGTERM"); } catch {}
      const quitDeadline = Date.now() + 5_000;
      while (await findSimulatorWindow()) {
        if (Date.now() >= quitDeadline) throw new Error("Connect IQ Simulator did not quit cleanly");
        await new Promise(resolve => setTimeout(resolve, 200));
      }
    }
    await run("connectiq", [], { timeout: 5_000 }).catch(() => undefined);
    const deadline = Date.now() + launchTimeout;
    while (!await findSimulatorWindow()) {
      if (Date.now() >= deadline) throw new Error("Connect IQ Simulator did not restart");
      await new Promise(resolve => setTimeout(resolve, 250));
    }
  }

  close() {
    for (const session of this.active) session.close();
    this.active.clear();
  }
}
