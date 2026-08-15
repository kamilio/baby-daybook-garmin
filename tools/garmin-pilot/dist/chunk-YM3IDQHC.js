// src/macos.ts
import { access } from "fs/promises";
import { basename, dirname } from "path";

// src/process.ts
import { execFile } from "child_process";
import { promisify } from "util";
var execFileAsync = promisify(execFile);
async function run(command, args = [], options = {}) {
  try {
    return await execFileAsync(command, args, {
      cwd: options.cwd,
      timeout: options.timeout ?? 3e4,
      maxBuffer: 16 * 1024 * 1024
    });
  } catch (error) {
    const detail = error;
    throw new Error(`${command} failed: ${detail.stderr || detail.stdout || detail.message}`.trim(), { cause: error });
  }
}
async function commandExists(command) {
  try {
    await run("/usr/bin/which", [command]);
    return true;
  } catch {
    return false;
  }
}

// src/macos.ts
var windowScript = String.raw`
import CoreGraphics
import Foundation
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)! as! [[String: Any]]
for window in windows {
  let owner = String(describing: window[kCGWindowOwnerName as String] ?? "")
  guard owner.contains("Connect IQ Device Simulator") else { continue }
  let bounds = window[kCGWindowBounds as String] as! [String: Any]
  let result: [String: Any] = [
    "id": window[kCGWindowNumber as String]!, "pid": window[kCGWindowOwnerPID as String]!,
    "title": window[kCGWindowName as String] ?? "", "x": bounds["X"]!, "y": bounds["Y"]!,
    "width": bounds["Width"]!, "height": bounds["Height"]!
  ]
  let data = try! JSONSerialization.data(withJSONObject: result)
  print(String(data: data, encoding: .utf8)!)
  break
}`;
async function findSimulatorWindow() {
  const { stdout } = await run("/usr/bin/swift", ["-e", windowScript], { timeout: 3e4 });
  const line = stdout.trim();
  return line ? JSON.parse(line) : null;
}
async function isAccessibilityTrusted() {
  const { stdout } = await run("/usr/bin/swift", ["-e", "import ApplicationServices; print(AXIsProcessTrusted())"]);
  return stdout.trim() === "true";
}
async function focusSimulator() {
  await run("/usr/bin/osascript", ["-e", 'tell application "System Events" to tell process "simulator" to set frontmost to true']);
  await new Promise((resolve4) => setTimeout(resolve4, 75));
}
async function click(x, y, holdMs = 0) {
  if (!await isAccessibilityTrusted()) {
    throw new Error("Accessibility permission is required for interactive simulator input");
  }
  if (!await commandExists("cliclick")) {
    throw new Error("cliclick is required for simulator input. Install it with: brew install cliclick");
  }
  await focusSimulator();
  const point = `${Math.round(x)},${Math.round(y)}`;
  if (holdMs <= 0) await run("cliclick", ["-r", `c:${point}`]);
  else {
    await run("cliclick", ["-r", `dd:${point}`, `w:${holdMs}`, `du:${point}`], { timeout: holdMs + 5e3 });
  }
}
async function drag(from, to, durationMs) {
  if (!await isAccessibilityTrusted()) {
    throw new Error("Accessibility permission is required for interactive simulator input");
  }
  if (!await commandExists("cliclick")) throw new Error("cliclick is required. Install it with: brew install cliclick");
  await focusSimulator();
  const commands = [
    "-r",
    "-e",
    durationMs <= 100 ? "1" : "2",
    `dd:${Math.round(from.x)},${Math.round(from.y)}`,
    `dm:${Math.round(to.x)},${Math.round(to.y)}`,
    `du:${Math.round(to.x)},${Math.round(to.y)}`
  ];
  await run("cliclick", commands, { timeout: durationMs + 5e3 });
}
async function captureWindow(windowId, path) {
  await run("/usr/sbin/screencapture", ["-x", "-o", "-l", String(windowId), path]);
  await access(path);
}
async function captureDevice(path) {
  const script = String.raw`
on run argv
  set destinationFolder to item 1 of argv
  set destinationName to item 2 of argv
  tell application "System Events"
    tell process "simulator"
      set frontmost to true
      if exists window "Save" then
        key code 53
        delay 0.2
      end if
      click menu item "Save Screen Capture" of menu "File" of menu bar 1
      delay 0.4
      keystroke "g" using {command down, shift down}
      delay 0.2
      keystroke destinationFolder
      key code 36
      delay 0.7
      tell splitter group 1 of window "Save"
        set value of attribute "AXValue" of text field 1 to destinationName
        click button "Save"
      end tell
    end tell
  end tell
end run`;
  await run("/usr/bin/osascript", ["-e", script, "--", dirname(path), basename(path)]);
  const deadline = Date.now() + 15e3;
  while (Date.now() < deadline) {
    try {
      await access(path);
      return;
    } catch {
    }
    await new Promise((resolve4) => setTimeout(resolve4, 50));
  }
  throw new Error(`Garmin native screen capture was not saved to ${path}`);
}

// src/garmin-session.ts
import { createHash } from "crypto";
import { readFile, unlink } from "fs/promises";
import { stat } from "fs/promises";
import { tmpdir } from "os";
import { join } from "path";
import { resolve } from "path";
async function snapshotCrashLog() {
  const path = join(tmpdir(), "com.garmin.connectiq/GARMIN/APPS/LOGS/CIQ_LOG.YML");
  try {
    const [metadata, content] = await Promise.all([stat(path), readFile(path)]);
    return { path, exists: true, size: metadata.size, mtimeMs: metadata.mtimeMs, hash: createHash("sha256").update(content).digest("hex") };
  } catch {
    return { path, exists: false, size: 0, mtimeMs: 0 };
  }
}
var BUTTON_IDS = { Light: "power", Up: "up", Down: "down", Start: "enter", Back: "esc", Menu: "menu" };
var GarminSession = class {
  constructor(device, windowInfo, prg, loaderPid, crashBaseline, profile) {
    this.device = device;
    this.windowInfo = windowInfo;
    this.prg = prg;
    this.loaderPid = loaderPid;
    this.crashBaseline = crashBaseline;
    this.profile = profile;
  }
  device;
  windowInfo;
  prg;
  loaderPid;
  crashBaseline;
  profile;
  get window() {
    return { ...this.windowInfo };
  }
  async refreshWindow() {
    const next = await findSimulatorWindow();
    if (!next) throw new Error("Connect IQ Simulator window disappeared");
    this.windowInfo = next;
    return this.window;
  }
  imageMetrics() {
    if (!this.profile) throw new Error(`No simulator profile loaded for ${this.device}`);
    const scale = this.windowInfo.width / this.profile.imageWidth;
    const renderedHeight = this.profile.imageHeight * scale;
    return { scale, top: (this.windowInfo.height - renderedHeight) / 2 };
  }
  profileRectCenter(rect) {
    const { scale, top } = this.imageMetrics();
    return {
      x: this.windowInfo.x + (rect.x + rect.width / 2) * scale,
      y: this.windowInfo.y + top + (rect.y + rect.height / 2) * scale
    };
  }
  keyFor(button) {
    const id = BUTTON_IDS[button];
    const key = this.profile?.keys.find((item) => item.id === id);
    if (!key) throw new Error(`${button} is not exposed by the ${this.device} simulator profile`);
    return key;
  }
  screenPoint(point) {
    if (point.x < 0 || point.x > 1 || point.y < 0 || point.y > 1) {
      throw new Error("Touch coordinates must be normalized from 0 to 1");
    }
    const display = this.profile?.display;
    if (!display) throw new Error(`No display geometry loaded for ${this.device}`);
    const { scale, top } = this.imageMetrics();
    return {
      x: this.windowInfo.x + (display.x + point.x * display.width) * scale,
      y: this.windowInfo.y + top + (display.y + point.y * display.height) * scale
    };
  }
  async press(button, options = {}) {
    await this.refreshWindow();
    const key = this.keyFor(button);
    const holdMs = key.isHold ? options.holdMs ?? 800 : options.holdMs ?? 0;
    const target = this.profileRectCenter(key.location);
    await click(target.x, target.y, holdMs);
    await this.waitForQuiet(options.settleMs ?? 150);
  }
  async tap(point, options = {}) {
    await this.refreshWindow();
    const target = this.screenPoint(point);
    await click(target.x, target.y);
    await this.waitForQuiet(options.settleMs ?? 150);
  }
  async swipe(from, to, options = {}) {
    await this.refreshWindow();
    await drag(this.screenPoint(from), this.screenPoint(to), options.durationMs ?? 250);
    await this.waitForQuiet(options.settleMs ?? 150);
  }
  async screenshot(options) {
    await this.refreshWindow();
    const path = resolve(options.path);
    const region = options.region ?? "window";
    if (region === "window") {
      await captureWindow(this.windowInfo.id, path);
    } else if (region === "framebuffer") {
      await unlink(path).catch(() => void 0);
      await captureDevice(path);
    } else {
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
        await run("/usr/bin/sips", ["-z", String(display.height * 2), String(display.width * 2), cropped, "--out", path]);
      } finally {
        await unlink(whole).catch(() => void 0);
        await unlink(cropped).catch(() => void 0);
      }
    }
    return { path, window: this.window };
  }
  async screenshotHash(path) {
    return createHash("sha256").update(await readFile(path)).digest("hex");
  }
  async waitForScreenshotChange(previousPath, options = {}) {
    const previous = await this.screenshotHash(previousPath);
    const timeout = options.timeout ?? 5e3;
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
  async waitForQuiet(ms = 150) {
    await new Promise((resolve4) => setTimeout(resolve4, ms));
  }
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
      try {
        process.kill(-this.loaderPid, "SIGINT");
      } catch {
      }
      this.loaderPid = void 0;
    }
  }
};

// src/device-profile.ts
import { readFile as readFile2 } from "fs/promises";
import { homedir } from "os";
import { dirname as dirname2, join as join2, resolve as resolve2 } from "path";
function defaultDevicesRoot() {
  return join2(homedir(), "Library/Application Support/Garmin/ConnectIQ/Devices");
}
async function pngDimensions(path) {
  const data = await readFile2(path);
  if (data.length < 24 || data.toString("ascii", 1, 4) !== "PNG") throw new Error(`Unsupported simulator image: ${path}`);
  return { width: data.readUInt32BE(16), height: data.readUInt32BE(20) };
}
async function loadDeviceProfile(device, devicesRoot = process.env.GARMIN_CONNECTIQ_DEVICES || defaultDevicesRoot()) {
  const directory = resolve2(devicesRoot, device);
  const simulatorPath = join2(directory, "simulator.json");
  let json;
  try {
    json = JSON.parse(await readFile2(simulatorPath, "utf8"));
  } catch (error) {
    throw new Error(`Could not load Connect IQ device profile ${device} from ${simulatorPath}`, { cause: error });
  }
  if (!json.image || !json.display?.location) throw new Error(`Invalid Connect IQ simulator profile: ${simulatorPath}`);
  const imagePath = resolve2(dirname2(simulatorPath), json.image);
  const dimensions = await pngDimensions(imagePath);
  return {
    device,
    directory,
    imagePath,
    imageWidth: dimensions.width,
    imageHeight: dimensions.height,
    display: { ...json.display.location, isTouch: json.display.isTouch === true, shape: json.display.shape },
    keys: json.keys ?? []
  };
}

// src/garmin-pilot.ts
import { resolve as resolve3 } from "path";
import { basename as basename2, join as join3 } from "path";
import { spawn } from "child_process";
import { readFile as readFile3, readdir, stat as stat2 } from "fs/promises";
import { tmpdir as tmpdir2 } from "os";
import { createHash as createHash2 } from "crypto";
async function snapshotSimulatorMedia(directory) {
  const snapshot = /* @__PURE__ */ new Map();
  for (const name of await readdir(directory).catch(() => [])) {
    const metadata = await stat2(join3(directory, name)).catch(() => null);
    if (metadata?.isFile()) snapshot.set(name, { mtimeMs: metadata.mtimeMs, size: metadata.size });
  }
  return snapshot;
}
function mediaChanged(before, after) {
  for (const [name, metadata] of after) {
    const previous = before.get(name);
    if (!previous || previous.mtimeMs !== metadata.mtimeMs || previous.size !== metadata.size) return true;
  }
  return false;
}
async function simulatorHasProgram(directory, expectedHash) {
  for (const name of await readdir(directory).catch(() => [])) {
    if (!name.toUpperCase().endsWith(".PRG")) continue;
    const content = await readFile3(join3(directory, name)).catch(() => null);
    if (content && createHash2("sha256").update(content).digest("hex") === expectedHash) return true;
  }
  return false;
}
var GarminPilot = class _GarminPilot {
  active = /* @__PURE__ */ new Set();
  static async launch(options = {}) {
    if (process.platform !== "darwin") throw new Error("Garmin Pilot currently supports macOS only");
    if (!await findSimulatorWindow()) {
      await run("connectiq", [], { timeout: 5e3 }).catch(() => void 0);
      const deadline = Date.now() + (options.launchTimeout ?? 15e3);
      while (!await findSimulatorWindow()) {
        if (Date.now() >= deadline) throw new Error("Connect IQ Simulator did not open within 15 seconds");
        await new Promise((resolve4) => setTimeout(resolve4, 250));
      }
    }
    return new _GarminPilot();
  }
  async newSession(options) {
    const cwd = options.cwd ? resolve3(options.cwd) : process.cwd();
    const prg = resolve3(cwd, options.prg);
    const crashBaseline = await snapshotCrashLog();
    const profile = await loadDeviceProfile(options.device);
    const mediaDirectory = join3(tmpdir2(), "com.garmin.connectiq/GARMIN/APPS/MEDIA");
    const mediaBefore = await snapshotSimulatorMedia(mediaDirectory);
    const requestedHash = createHash2("sha256").update(await readFile3(prg)).digest("hex");
    const loader = spawn("monkeydo", [prg, options.device], { cwd, detached: true, stdio: "ignore" });
    loader.unref();
    const deadline = Date.now() + (options.launchTimeout ?? 15e3);
    let window = await findSimulatorWindow();
    let mediaAfter = await snapshotSimulatorMedia(mediaDirectory);
    let requestedProgramInstalled = await simulatorHasProgram(mediaDirectory, requestedHash);
    const isRequestedDeviceLoaded = () => {
      if (!window || !window.title.startsWith("CIQ Simulator -")) return false;
      const renderedImageHeight = window.height - 56;
      if (renderedImageHeight <= 0) return false;
      return Math.abs(window.width / renderedImageHeight - profile.imageWidth / profile.imageHeight) < 0.02;
    };
    const isProgramPushed = () => mediaChanged(mediaBefore, mediaAfter) || requestedProgramInstalled;
    while ((!isRequestedDeviceLoaded() || !isProgramPushed()) && Date.now() < deadline) {
      await new Promise((resolve4) => setTimeout(resolve4, 200));
      window = await findSimulatorWindow();
      mediaAfter = await snapshotSimulatorMedia(mediaDirectory);
      requestedProgramInstalled = await simulatorHasProgram(mediaDirectory, requestedHash);
    }
    if (!window || !isRequestedDeviceLoaded() || !isProgramPushed()) {
      try {
        if (loader.pid) process.kill(-loader.pid, "SIGINT");
      } catch {
      }
      throw new Error(`Connect IQ Simulator did not load ${basename2(prg)} for ${options.device} within ${options.launchTimeout ?? 15e3}ms`);
    }
    await new Promise((resolve4) => setTimeout(resolve4, 500));
    const session = new GarminSession(options.device, window, prg, loader.pid, crashBaseline, profile);
    this.active.add(session);
    return session;
  }
  sessions() {
    return [...this.active];
  }
  async restartSimulator(launchTimeout = 15e3) {
    this.close();
    const existing = await findSimulatorWindow();
    if (existing) {
      try {
        process.kill(existing.pid, "SIGTERM");
      } catch {
      }
      const quitDeadline = Date.now() + 5e3;
      while (await findSimulatorWindow()) {
        if (Date.now() >= quitDeadline) throw new Error("Connect IQ Simulator did not quit cleanly");
        await new Promise((resolve4) => setTimeout(resolve4, 200));
      }
    }
    await run("connectiq", [], { timeout: 5e3 }).catch(() => void 0);
    const deadline = Date.now() + launchTimeout;
    while (!await findSimulatorWindow()) {
      if (Date.now() >= deadline) throw new Error("Connect IQ Simulator did not restart");
      await new Promise((resolve4) => setTimeout(resolve4, 250));
    }
  }
  close() {
    for (const session of this.active) session.close();
    this.active.clear();
  }
};

export {
  isAccessibilityTrusted,
  snapshotCrashLog,
  GarminSession,
  loadDeviceProfile,
  GarminPilot
};
