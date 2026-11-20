// Brainrot Carnival — submission harness (Node 22, standard library only, no network).
// Copies game.rbxl, PLAY.json, screenshots/ and src/ into the output directory and
// writes dossier.json there with the kit's vendor library.

import { copyFileSync, mkdirSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const repoRoot = dirname(fileURLToPath(import.meta.url));
const outDir = process.env.MAKEFUN_OUTPUT_DIR || join(repoRoot, "output");
mkdirSync(outDir, { recursive: true });

const dossier = buildDossier(repoRoot, { text_max_bytes: 65536 });

let copied = 0;

function copyEntry(src: string, dest: string): void {
  const st = statSync(src);
  if (st.isDirectory()) {
    mkdirSync(dest, { recursive: true });
    for (const entry of readdirSync(src)) {
      // Dot-names fail an entry, so they are left out.
      if (entry.startsWith('.')) continue;
      copyEntry(join(src, entry), join(dest, entry));
    }
  } else if (st.isFile()) {
    copyFileSync(src, dest);
    copied += 1;
  }
}

copyEntry(join(repoRoot, 'game.rbxl'), join(outDir, 'game.rbxl'));
copyEntry(join(repoRoot, 'PLAY.json'), join(outDir, 'PLAY.json'));
copyEntry(join(repoRoot, 'screenshots'), join(outDir, 'screenshots'));
copyEntry(join(repoRoot, 'src'), join(outDir, 'src'));

writeFileSync(join(outDir, 'dossier.json'), dossier);
console.log(`copied ${copied} files`);
console.log(`dossier.json: ${dossier.length} bytes`);
