type WindowInfo = {
    id: number;
    pid: number;
    title: string;
    x: number;
    y: number;
    width: number;
    height: number;
};
declare function isAccessibilityTrusted(): Promise<boolean>;

type Rect = {
    x: number;
    y: number;
    width: number;
    height: number;
};
type DeviceKey = {
    id: string;
    behavior?: string;
    isHold?: boolean;
    location: Rect;
};
type DeviceProfile = {
    device: string;
    directory: string;
    imagePath: string;
    imageWidth: number;
    imageHeight: number;
    display: Rect & {
        isTouch: boolean;
        shape?: string;
    };
    keys: DeviceKey[];
};
declare function loadDeviceProfile(device: string, devicesRoot?: string): Promise<DeviceProfile>;

type GarminButton = "Light" | "Up" | "Down" | "Start" | "Back" | "Menu";
type Point = {
    x: number;
    y: number;
};
type ScreenshotOptions = {
    path: string;
    region?: "window" | "device" | "framebuffer";
};
type CrashLogSnapshot = {
    path: string;
    exists: boolean;
    size: number;
    mtimeMs: number;
    hash?: string;
};
declare function snapshotCrashLog(): Promise<CrashLogSnapshot>;
declare class GarminSession {
    readonly device: string;
    private windowInfo;
    readonly prg?: string | undefined;
    private loaderPid?;
    readonly crashBaseline?: CrashLogSnapshot | undefined;
    readonly profile?: DeviceProfile | undefined;
    constructor(device: string, windowInfo: WindowInfo, prg?: string | undefined, loaderPid?: number | undefined, crashBaseline?: CrashLogSnapshot | undefined, profile?: DeviceProfile | undefined);
    get window(): {
        id: number;
        pid: number;
        title: string;
        x: number;
        y: number;
        width: number;
        height: number;
    };
    refreshWindow(): Promise<{
        id: number;
        pid: number;
        title: string;
        x: number;
        y: number;
        width: number;
        height: number;
    }>;
    private imageMetrics;
    private profileRectCenter;
    private keyFor;
    private screenPoint;
    press(button: GarminButton, options?: {
        holdMs?: number;
        settleMs?: number;
    }): Promise<void>;
    tap(point: Point, options?: {
        settleMs?: number;
    }): Promise<void>;
    swipe(from: Point, to: Point, options?: {
        durationMs?: number;
        settleMs?: number;
    }): Promise<void>;
    screenshot(options: ScreenshotOptions): Promise<{
        path: string;
        window: {
            id: number;
            pid: number;
            title: string;
            x: number;
            y: number;
            width: number;
            height: number;
        };
    }>;
    screenshotHash(path: string): Promise<string>;
    waitForScreenshotChange(previousPath: string, options?: {
        timeout?: number;
        pollMs?: number;
        outputPath?: string;
        region?: ScreenshotOptions["region"];
    }): Promise<{
        path: string;
    }>;
    waitForQuiet(ms?: number): Promise<void>;
    assertNoNewCrash(): Promise<{
        ok: boolean;
        crashLog: string;
    }>;
    killApp(): Promise<void>;
    close(): void;
}

type NewSessionOptions = {
    device: string;
    prg: string;
    cwd?: string;
    launchTimeout?: number;
};
type LaunchOptions = {
    launchTimeout?: number;
};
declare class GarminPilot {
    private active;
    static launch(options?: LaunchOptions): Promise<GarminPilot>;
    newSession(options: NewSessionOptions): Promise<GarminSession>;
    sessions(): GarminSession[];
    restartSimulator(launchTimeout?: number): Promise<void>;
    close(): void;
}

export { type CrashLogSnapshot, type DeviceKey, type DeviceProfile, type GarminButton, GarminPilot, GarminSession, type LaunchOptions, type NewSessionOptions, type Point, type Rect, type ScreenshotOptions, type WindowInfo, isAccessibilityTrusted, loadDeviceProfile, snapshotCrashLog };
