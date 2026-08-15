import {
  GarminPilot
} from "./chunk-YM3IDQHC.js";

// src/toolcraft.ts
import { defineCommand, defineGroup, S } from "toolcraft";
import { createSDK } from "toolcraft/sdk";
var device = S.String({ description: "Connect IQ device id, for example fenix7" });
var prg = S.String({ description: "Path to the compiled .prg" });
var screenshotPath = S.String({ description: "Destination PNG path" });
var screenshotRegion = S.Optional(S.Enum(["window", "device", "framebuffer"], { default: "device" }));
var button = S.Enum(["Light", "Up", "Down", "Start", "Back", "Menu"]);
async function withSession(params, operation) {
  const pilot = await GarminPilot.launch();
  try {
    return await operation(await pilot.newSession(params));
  } finally {
    pilot.close();
  }
}
var capture = defineCommand({
  name: "screenshot",
  title: "Capture Garmin simulator screenshot",
  description: "Load a Connect IQ app and capture the visible simulator window",
  params: S.Object({ device, prg, path: screenshotPath, region: screenshotRegion }),
  result: S.Object({ path: S.String(), window: S.Json() }),
  annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false },
  handler: async ({ params }) => withSession(params, (value) => value.screenshot({ path: params.path, region: params.region }))
});
var press = defineCommand({
  name: "press",
  title: "Press Garmin simulator button",
  description: "Load a Connect IQ app, press a physical watch button, and optionally capture the result",
  params: S.Object({ device, prg, button, screenshot: S.Optional(screenshotPath) }),
  result: S.Object({ ok: S.Boolean(), screenshot: S.Optional(S.String()) }),
  annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false },
  handler: async ({ params }) => {
    return withSession(params, async (active) => {
      await active.press(params.button);
      if (params.screenshot) await active.screenshot({ path: params.screenshot });
      await active.assertNoNewCrash();
      return { ok: true, screenshot: params.screenshot };
    });
  }
});
var tap = defineCommand({
  name: "tap",
  title: "Tap Garmin simulator screen",
  description: "Load a Connect IQ app and tap normalized screen coordinates",
  params: S.Object({ device, prg, x: S.Number({ minimum: 0, maximum: 1 }), y: S.Number({ minimum: 0, maximum: 1 }), screenshot: S.Optional(screenshotPath) }),
  result: S.Object({ ok: S.Boolean(), screenshot: S.Optional(S.String()) }),
  annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false },
  handler: async ({ params }) => {
    return withSession(params, async (active) => {
      await active.tap({ x: params.x, y: params.y });
      if (params.screenshot) await active.screenshot({ path: params.screenshot });
      await active.assertNoNewCrash();
      return { ok: true, screenshot: params.screenshot };
    });
  }
});
var swipe = defineCommand({
  name: "swipe",
  title: "Experimentally swipe Garmin simulator screen",
  description: "Synthesize a macOS drag between normalized screen coordinates; Garmin exposes no supported simulator input API, so prefer scenario rendering for acceptance tests",
  params: S.Object({
    device,
    prg,
    fromX: S.Number({ minimum: 0, maximum: 1 }),
    fromY: S.Number({ minimum: 0, maximum: 1 }),
    toX: S.Number({ minimum: 0, maximum: 1 }),
    toY: S.Number({ minimum: 0, maximum: 1 }),
    durationMs: S.Optional(S.Number({ minimum: 50, maximum: 5e3, default: 250 })),
    screenshot: S.Optional(screenshotPath)
  }),
  result: S.Object({ ok: S.Boolean(), screenshot: S.Optional(S.String()) }),
  annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false },
  handler: async ({ params }) => withSession(params, async (active) => {
    await active.swipe({ x: params.fromX, y: params.fromY }, { x: params.toX, y: params.toY }, { durationMs: params.durationMs });
    if (params.screenshot) await active.screenshot({ path: params.screenshot });
    await active.assertNoNewCrash();
    return { ok: true, screenshot: params.screenshot };
  })
});
var garminPilotCommands = defineGroup({
  name: "garmin",
  description: "Automate the Garmin Connect IQ Simulator",
  children: [capture, press, tap, swipe]
});
function createGarminPilotToolcraftSDK() {
  return createSDK(garminPilotCommands);
}

export {
  garminPilotCommands,
  createGarminPilotToolcraftSDK
};
