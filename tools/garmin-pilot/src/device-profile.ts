import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

export type Rect = { x: number; y: number; width: number; height: number };
export type DeviceKey = { id: string; behavior?: string; isHold?: boolean; location: Rect };
export type DeviceProfile = {
  device: string;
  directory: string;
  imagePath: string;
  imageWidth: number;
  imageHeight: number;
  display: Rect & { isTouch: boolean; shape?: string };
  keys: DeviceKey[];
};

type SimulatorJson = {
  image: string;
  display: { isTouch?: boolean; shape?: string; location: Rect };
  keys?: DeviceKey[];
};

function defaultDevicesRoot() {
  return join(homedir(), "Library/Application Support/Garmin/ConnectIQ/Devices");
}

async function pngDimensions(path: string) {
  const data = await readFile(path);
  if (data.length < 24 || data.toString("ascii", 1, 4) !== "PNG") throw new Error(`Unsupported simulator image: ${path}`);
  return { width: data.readUInt32BE(16), height: data.readUInt32BE(20) };
}

export async function loadDeviceProfile(device: string, devicesRoot = process.env.GARMIN_CONNECTIQ_DEVICES || defaultDevicesRoot()): Promise<DeviceProfile> {
  const directory = resolve(devicesRoot, device);
  const simulatorPath = join(directory, "simulator.json");
  let json: SimulatorJson;
  try {
    json = JSON.parse(await readFile(simulatorPath, "utf8")) as SimulatorJson;
  } catch (error) {
    throw new Error(`Could not load Connect IQ device profile ${device} from ${simulatorPath}`, { cause: error });
  }
  if (!json.image || !json.display?.location) throw new Error(`Invalid Connect IQ simulator profile: ${simulatorPath}`);
  const imagePath = resolve(dirname(simulatorPath), json.image);
  const dimensions = await pngDimensions(imagePath);
  return {
    device,
    directory,
    imagePath,
    imageWidth: dimensions.width,
    imageHeight: dimensions.height,
    display: { ...json.display.location, isTouch: json.display.isTouch === true, shape: json.display.shape },
    keys: json.keys ?? [],
  };
}
