import { access } from "node:fs/promises";
import { basename, dirname } from "node:path";
import { run, commandExists } from "./process.js";

export type WindowInfo = {
  id: number;
  pid: number;
  title: string;
  x: number;
  y: number;
  width: number;
  height: number;
};

const windowScript = String.raw`
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

export async function findSimulatorWindow(): Promise<WindowInfo | null> {
  const { stdout } = await run("/usr/bin/swift", ["-e", windowScript], { timeout: 30_000 });
  const line = stdout.trim();
  return line ? JSON.parse(line) as WindowInfo : null;
}

export async function isAccessibilityTrusted() {
  const { stdout } = await run("/usr/bin/swift", ["-e", "import ApplicationServices; print(AXIsProcessTrusted())"]);
  return stdout.trim() === "true";
}

export async function focusSimulator() {
  await run("/usr/bin/osascript", ["-e", 'tell application "System Events" to tell process "simulator" to set frontmost to true']);
  await new Promise(resolve => setTimeout(resolve, 75));
}

export async function click(x: number, y: number, holdMs = 0) {
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
    await run("cliclick", ["-r", `dd:${point}`, `w:${holdMs}`, `du:${point}`], { timeout: holdMs + 5_000 });
  }
}

export async function drag(from: { x: number; y: number }, to: { x: number; y: number }, durationMs: number) {
  if (!await isAccessibilityTrusted()) {
    throw new Error("Accessibility permission is required for interactive simulator input");
  }
  if (!await commandExists("cliclick")) throw new Error("cliclick is required. Install it with: brew install cliclick");
  await focusSimulator();
  const commands = [
    "-r", "-e", durationMs <= 100 ? "1" : "2",
    `dd:${Math.round(from.x)},${Math.round(from.y)}`,
    `dm:${Math.round(to.x)},${Math.round(to.y)}`,
    `du:${Math.round(to.x)},${Math.round(to.y)}`,
  ];
  await run("cliclick", commands, { timeout: durationMs + 5_000 });
}

export async function captureWindow(windowId: number, path: string) {
  // -o excludes the macOS drop shadow, making pixels map directly to the
  // CGWindow bounds at the display scale.
  await run("/usr/sbin/screencapture", ["-x", "-o", "-l", String(windowId), path]);
  await access(path);
}

export async function captureDevice(path: string) {
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
  const deadline = Date.now() + 15_000;
  while (Date.now() < deadline) {
    try { await access(path); return; } catch {}
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  throw new Error(`Garmin native screen capture was not saved to ${path}`);
}
