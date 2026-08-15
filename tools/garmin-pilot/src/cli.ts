#!/usr/bin/env node
import { runCLI } from "toolcraft/cli";
import { runMCP } from "toolcraft/mcp";
import { garminPilotCommands } from "./toolcraft.js";

if (process.argv[2] === "mcp") {
  await runMCP(garminPilotCommands, { name: "garmin-pilot", version: "0.1.0", omitRootToolNamePrefix: true, errorReports: true });
} else {
  await runCLI(garminPilotCommands, {
    version: "0.1.0",
    rootUsageName: "garmin-pilot",
    casing: "kebab",
    controls: { output: true, debug: true, verbose: true, yes: true, help: "concise" },
    errorReports: true,
  });
}
