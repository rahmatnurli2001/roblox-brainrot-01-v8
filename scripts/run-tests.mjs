// scripts/run-tests.mjs
// Run every tests/*.luau file with the Luau CLI, collect PASS/FAIL lines,
// print per-file counts and a total. Exits 0 ONLY if every file passes.
// Node stdlib only. Run from the repo root:  node scripts/run-tests.mjs

import { spawnSync } from "node:child_process";
import { existsSync, readdirSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "..");
const testsDir = join(repoRoot, "tests");

function findLuau() {
  if (process.env.LUAU_BIN && existsSync(process.env.LUAU_BIN)) {
    return process.env.LUAU_BIN;
  }
  const candidates = [
    // Sibling repo that ships the Luau binary (see task brief).
    join(repoRoot, "..", "roblox-brainrot-01-v2", ".tools", "luau"),
    join(homedir(), "workspace", "makefun", "roblox-brainrot-01-v2", ".tools", "luau"),
  ];
  for (const candidate of candidates) {
    if (existsSync(candidate)) return candidate;
  }
  return null;
}

const luau = findLuau();
if (!luau) {
  console.error("ERROR: Luau binary not found. Set LUAU_BIN or place it at:");
  console.error("  ~/workspace/makefun/roblox-brainrot-01-v2/.tools/luau");
  process.exit(1);
}
if (!existsSync(testsDir)) {
  console.error(`ERROR: tests directory not found: ${testsDir}`);
  process.exit(1);
}

const files = readdirSync(testsDir)
  .filter((name) => name.endsWith(".luau"))
  .sort();
if (files.length === 0) {
  console.error(`ERROR: no .luau test files in ${testsDir}`);
  process.exit(1);
}

let totalPassed = 0;
let totalFailed = 0;
let allOk = true;

for (const file of files) {
  const fullPath = join(testsDir, file);
  const result = spawnSync(luau, [fullPath], {
    cwd: repoRoot,
    encoding: "utf8",
    timeout: 120000,
  });

  const output = `${result.stdout ?? ""}\n${result.stderr ?? ""}`;
  const lines = output.split(/\r?\n/);
  let passed = 0;
  let failed = 0;
  const failLines = [];
  for (const line of lines) {
    if (line.startsWith("PASS:")) passed += 1;
    else if (line.startsWith("FAIL:")) {
      failed += 1;
      failLines.push(line);
    }
  }

  const exitCode = result.status;
  const fileOk = exitCode === 0 && failed === 0 && result.error == null;
  if (!fileOk) allOk = false;
  totalPassed += passed;
  totalFailed += failed;

  const status = fileOk ? "PASS" : "FAIL";
  console.log(`${status} ${file}: ${passed} passed, ${failed} failed (exit ${exitCode})`);
  if (result.error) {
    console.log(`  runner error: ${result.error.message}`);
  }
  for (const line of failLines) {
    console.log(`  ${line}`);
  }
  if (!fileOk && failed === 0) {
    // Non-zero exit with no FAIL lines: a runtime error, not an assert.
    // Show the tail so the failure is diagnosable.
    const tail = lines.filter((l) => l.trim() !== "").slice(-8);
    for (const line of tail) {
      console.log(`  ${line}`);
    }
  }
}

console.log(`TOTAL: ${totalPassed} passed, ${totalFailed} failed across ${files.length} file(s)`);
process.exit(allOk ? 0 : 1);
