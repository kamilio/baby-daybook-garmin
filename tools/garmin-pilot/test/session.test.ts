import { beforeEach, describe, expect, it, vi } from "vitest";

const macos = vi.hoisted(() => ({
  click: vi.fn(),
  drag: vi.fn(),
  findSimulatorWindow: vi.fn(),
  captureWindow: vi.fn(),
  captureDevice: vi.fn(),
}));

vi.mock("../src/macos.js", () => macos);
import { GarminSession } from "../src/garmin-session.js";
import type { DeviceProfile } from "../src/device-profile.js";

const window = { id: 1, pid: 2, title: "CIQ", x: 10, y: 20, width: 400, height: 600 };
const profile: DeviceProfile = {
  device: "testwatch",
  directory: "/tmp/testwatch",
  imagePath: "/tmp/testwatch/watch.png",
  imageWidth: 400,
  imageHeight: 600,
  display: { x: 50, y: 100, width: 300, height: 300, isTouch: true, shape: "round" },
  keys: [{ id: "enter", behavior: "onSelect", isHold: false, location: { x: 360, y: 120, width: 40, height: 60 } }],
};

beforeEach(() => {
  vi.clearAllMocks();
  macos.findSimulatorWindow.mockResolvedValue(window);
  macos.click.mockResolvedValue(undefined);
});

describe("GarminSession", () => {
  it("exposes immutable window geometry", () => {
    const session = new GarminSession("fenix7", window);
    const first = session.window;
    first.x = 999;
    expect(session.window.x).toBe(10);
  });

  it("maps normalized touch coordinates into the profile display", async () => {
    const session = new GarminSession("testwatch", window, undefined, undefined, undefined, profile);
    await session.tap({ x: 0.5, y: 0.5 }, { settleMs: 0 });
    expect(macos.click).toHaveBeenCalledWith(210, 270);
  });

  it("maps Garmin behavior names to physical key geometry", async () => {
    const session = new GarminSession("testwatch", window, undefined, undefined, undefined, profile);
    await session.press("Start", { settleMs: 0 });
    expect(macos.click).toHaveBeenCalledWith(390, 170, 0);
  });

  it("rejects touch coordinates outside the normalized display", async () => {
    const session = new GarminSession("testwatch", window, undefined, undefined, undefined, profile);
    await expect(session.tap({ x: 1.01, y: 0.5 }, { settleMs: 0 }))
      .rejects.toThrow("Touch coordinates must be normalized from 0 to 1");
    expect(macos.click).not.toHaveBeenCalled();
  });
});
