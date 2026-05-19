import { execSync } from "child_process";
import path from "path";

export function runScript(
  projectRoot: string,
  scriptName: string,
  args: string[]
): unknown {
  const scriptDir = process.env.SDLC_SCRIPTS_DIR || path.join(projectRoot, "scripts");
  const scriptPath = path.join(scriptDir, `${scriptName}.sh`);
  const quotedArgs = args
    .map((a) => `'${a.replace(/'/g, "'\\''")}'`)
    .join(" ");
  const cmd = quotedArgs ? `${scriptPath} ${quotedArgs}` : scriptPath;

  let output: string;
  try {
    output = execSync(cmd, {
      env: { ...process.env },
      cwd: projectRoot,
      encoding: "utf-8",
    });
  } catch (err) {
    throw new Error(
      `Script '${scriptName}' failed: ${err instanceof Error ? err.message : String(err)}`
    );
  }

  try {
    return JSON.parse(output.trim());
  } catch {
    throw new Error(
      `Script '${scriptName}' output is not valid JSON: ${output.trim().slice(0, 200)}`
    );
  }
}
