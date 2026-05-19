#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const require = createRequire(import.meta.url);
const result = spawnSync(process.execPath, [require.resolve("tsx/cli"), path.join(packageRoot, "mcp", "sdlc-mcp", "src", "index.ts"), ...process.argv.slice(2)], {
  cwd: process.cwd(),
  env: {
    ...process.env,
    SDLC_PACKAGE_ROOT: packageRoot,
    SDLC_SCRIPTS_DIR: path.join(packageRoot, "scripts"),
  },
  stdio: "inherit",
});

process.exit(result.status ?? 1);
