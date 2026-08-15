import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export async function run(command: string, args: string[] = [], options: { cwd?: string; timeout?: number } = {}) {
  try {
    return await execFileAsync(command, args, {
      cwd: options.cwd,
      timeout: options.timeout ?? 30_000,
      maxBuffer: 16 * 1024 * 1024,
    });
  } catch (error) {
    const detail = error as Error & { stderr?: string; stdout?: string };
    throw new Error(`${command} failed: ${detail.stderr || detail.stdout || detail.message}`.trim(), { cause: error });
  }
}

export async function commandExists(command: string) {
  try {
    await run("/usr/bin/which", [command]);
    return true;
  } catch {
    return false;
  }
}
