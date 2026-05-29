#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { copyFile, cp } from "node:fs/promises";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const require = createRequire(import.meta.url);

function usage() {
  console.log(`oh-my-sdlc

Usage:
  sdlc init [--project <dir>]
  sdlc install [claude|codex|gemini|antigravity|all] [--project <dir>]
  sdlc start [claude|gemini|antigravity] [--project <dir>]
  sdlc mcp --config <path>
  sdlc doctor [--project <dir>]
`);
}

function parseArgs(argv) {
  const args = [...argv];
  const command = args.shift() ?? "help";
  let project = process.cwd();
  const rest = [];

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === "--project") {
      const value = args[i + 1];
      if (!value) throw new Error("--project requires a directory");
      project = path.resolve(value);
      i += 1;
    } else {
      rest.push(arg);
    }
  }

  return { command, project, rest };
}

function mcpConfigForProject() {
  return {
    mcpServers: {
      sdlc: {
        command: "sdlc-mcp",
        args: ["--config", ".sdlc/config.json"],
      },
    },
  };
}

function codexConfig() {
  return `[mcp_servers.sdlc]
command = "sdlc-mcp"
args = ["--config", ".sdlc/config.json"]
`;
}

function geminiExtensionConfig() {
  return {
    name: "oh-my-sdlc",
    version: "0.1.0",
    mcpServers: mcpConfigForProject().mcpServers,
    contextFileName: "GEMINI.md",
  };
}

function antigravityMcpConfig(project) {
  return {
    mcpServers: {
      sdlc: {
        command: "sdlc-mcp",
        args: ["--config", path.join(project, ".sdlc", "config.json")],
        cwd: project,
      },
    },
  };
}

function installAntigravityCliPlugin(project) {
  if (process.env.SDLC_SKIP_ANTIGRAVITY_PLUGIN_INSTALL === "1") return;

  const pluginDir = path.join(project, "plugins", "antigravity-cli");
  const result = spawnSync("agy", ["plugin", "install", pluginDir], {
    cwd: project,
    env: process.env,
    stdio: "inherit",
  });

  if (result.error?.code === "ENOENT") {
    console.warn(`Antigravity CLI not found; run "agy plugin install ${pluginDir}" after installing agy.`);
    return;
  }
  if ((result.status ?? 1) !== 0) {
    throw new Error(`Failed to install Antigravity CLI plugin from ${pluginDir}`);
  }
}

async function copyIfExists(src, dest) {
  if (!existsSync(src)) return;
  if (path.resolve(src) === path.resolve(dest)) return;
  await cp(src, dest, { 
    recursive: true, 
    force: true,
    filter: (source) => {
      const basename = path.basename(source);
      return basename !== "node_modules" && basename !== "dist";
    }
  });
}

async function installAssets(project) {
  mkdirSync(project, { recursive: true });
  for (const dir of ["scripts", "mcp", "skills"]) {
    await copyIfExists(path.join(packageRoot, dir), path.join(project, dir));
  }
  for (const file of ["AGENTS.md", "CLAUDE.md", "GEMINI.md"]) {
    await copyIfExists(path.join(packageRoot, file), path.join(project, file));
  }
  // Copy upstream feedback config (isolated from project config.json)
  const upstreamSrc = path.join(packageRoot, ".sdlc", "upstream.json");
  const upstreamDest = path.join(project, ".sdlc", "upstream.json");
  mkdirSync(path.join(project, ".sdlc"), { recursive: true });
  await copyIfExists(upstreamSrc, upstreamDest);
}

function writeJson(file, value) {
  mkdirSync(path.dirname(file), { recursive: true });
  writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

function readJsonObject(file) {
  if (!existsSync(file)) return {};
  const parsed = JSON.parse(readFileSync(file, "utf8"));
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error(`${file} must contain a JSON object`);
  }
  return parsed;
}

function upsertGeminiSettings(project) {
  const settingsFile = path.join(project, ".gemini", "settings.json");
  const settings = readJsonObject(settingsFile);
  const mcpServers =
    settings.mcpServers && typeof settings.mcpServers === "object" && !Array.isArray(settings.mcpServers)
      ? settings.mcpServers
      : {};

  settings.mcpServers = {
    ...mcpServers,
    sdlc: mcpConfigForProject().mcpServers.sdlc,
  };

  writeJson(settingsFile, settings);
}

function appendCodexMcpConfig(project) {
  const configDir = path.join(project, ".codex");
  const configFile = path.join(configDir, "config.toml");
  mkdirSync(configDir, { recursive: true });

  const block = codexConfig();
  const existing = existsSync(configFile) ? readFileSync(configFile, "utf8") : "";
  if (existing.includes("[mcp_servers.sdlc]")) return;
  const prefix = existing.trim() ? `${existing.trimEnd()}\n\n` : "";
  writeFileSync(configFile, `${prefix}${block}`);
}

async function installTool(project, tool) {
  await installAssets(project);

  if (tool === "claude" || tool === "all") {
    writeJson(path.join(project, ".claude", "mcp.json"), mcpConfigForProject());
  }
  if (tool === "gemini" || tool === "all") {
    upsertGeminiSettings(project);
    writeJson(path.join(project, ".gemini", "extensions", "oh-my-sdlc", "gemini-extension.json"), geminiExtensionConfig());
  }
  if (tool === "antigravity" || tool === "all") {
    writeJson(path.join(project, "plugins", "antigravity-cli", "plugin.json"), { name: "oh-my-sdlc" });
    writeJson(path.join(project, "plugins", "antigravity-cli", "mcp_config.json"), antigravityMcpConfig(project));
    installAntigravityCliPlugin(project);
  }
  if (tool === "codex" || tool === "all") {
    appendCodexMcpConfig(project);
  }
}

function runInit(project) {
  const script = path.join(project, "scripts", "init.sh");
  if (!existsSync(script)) throw new Error(`Missing ${script}; run sdlc install first`);
  const result = spawnSync("bash", [script], {
    cwd: project,
    env: { ...process.env, PROJECT_ROOT: project },
    stdio: "inherit",
  });
  process.exit(result.status ?? 1);
}

function runMcp(args) {
  const result = spawnSync(process.execPath, [require.resolve("tsx/cli"), path.join(packageRoot, "mcp", "sdlc-mcp", "src", "index.ts"), ...args], {
    cwd: process.cwd(),
    env: {
      ...process.env,
      SDLC_PACKAGE_ROOT: packageRoot,
      SDLC_SCRIPTS_DIR: path.join(packageRoot, "scripts"),
    },
    stdio: "inherit",
  });
  process.exit(result.status ?? 1);
}

function doctor(project) {
  const checks = [
    ["project", project, statSync(project).isDirectory()],
    ["AGENTS.md", path.join(project, "AGENTS.md"), existsSync(path.join(project, "AGENTS.md"))],
    [".sdlc/config.json", path.join(project, ".sdlc", "config.json"), existsSync(path.join(project, ".sdlc", "config.json"))],
    [".claude/mcp.json", path.join(project, ".claude", "mcp.json"), existsSync(path.join(project, ".claude", "mcp.json"))],
    [".gemini/settings.json", path.join(project, ".gemini", "settings.json"), existsSync(path.join(project, ".gemini", "settings.json"))],
    ["plugins/antigravity-cli/mcp_config.json", path.join(project, "plugins", "antigravity-cli", "mcp_config.json"), existsSync(path.join(project, "plugins", "antigravity-cli", "mcp_config.json"))],
    [".codex/config.toml", path.join(project, ".codex", "config.toml"), existsSync(path.join(project, ".codex", "config.toml"))],
  ];

  for (const [name, file, ok] of checks) {
    console.log(`${ok ? "ok" : "missing"} ${name} ${file}`);
  }
}

try {
  const { command, project, rest } = parseArgs(process.argv.slice(2));
  if (command === "help" || command === "--help" || command === "-h") {
    usage();
  } else if (command === "install") {
    const tool = rest[0] ?? "all";
    if (!["claude", "codex", "gemini", "antigravity", "all"].includes(tool)) throw new Error(`Unknown tool: ${tool}`);
    await installTool(project, tool);
    console.log(`Installed oh-my-sdlc for ${tool} in ${project}`);
  } else if (command === "init") {
    await installTool(project, "all");
    runInit(project);
  } else if (command === "mcp") {
    runMcp(rest);
  } else if (command === "start") {
    const tool = rest[0];
    if (tool === "claude") {
      spawnSync("claude", ["-p", "请阅读 CLAUDE.md，然后开始工作并持续自动执行直到没有任务。"], { cwd: project, stdio: "inherit" });
    } else if (tool === "antigravity" || tool === "agy") {
      spawnSync("agy", ["-i", "请按 oh-my-sdlc 规则开始工作并持续自动执行直到没有任务。"], { cwd: project, stdio: "inherit" });
    } else if (tool === "gemini") {
      spawnSync("gemini", ["--prompt-interactive", "请阅读 GEMINI.md，然后开始工作并持续自动执行直到没有任务。"], { cwd: project, stdio: "inherit" });
    } else {
      console.log("Usage: sdlc start [claude|antigravity|gemini]");
    }
  } else if (command === "doctor") {
    doctor(project);
  } else {
    usage();
    process.exitCode = 1;
  }
} catch (err) {
  console.error(`sdlc: ${err instanceof Error ? err.message : String(err)}`);
  process.exitCode = 1;
}
