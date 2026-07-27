#!/usr/bin/env node

/**
 * Ink Rendering Patcher for Squad CLI (patched for ink 7.x)
 *
 * Patches ink/build/ink.js to fix scroll flicker on Windows Terminal.
 * Three patches are applied:
 *
 * 1. Remove trailing newline — in ink 7.x the newline is already conditional
 *    on isFullscreen; we force it to always be omitted so logUpdate's
 *    previousLineCount stays correct on non-fullscreen output too.
 *
 * 2. Disable clearTerminal shouldClearTerminal path — when output fills the
 *    terminal, Ink clears the entire screen, causing violent scroll-to-top
 *    flicker.  We force the condition to `false` so logUpdate's incremental
 *    erase-and-rewrite is always used instead.
 *
 * 3. Verify incrementalRendering passthrough — confirms that Ink forwards
 *    the incrementalRendering option to logUpdate.create(). No code change
 *    needed if already wired up.
 *
 * All patches are idempotent (safe to run multiple times).
 *
 * NOTE: This file replaces the upstream patch-ink-rendering.mjs so that the
 * search patterns match ink 7.x (the originals targeted an older ink API).
 */

import { readFileSync, writeFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

function patchInkRendering() {
  // Try multiple possible locations (npm workspaces can hoist dependencies)
  const possiblePaths = [
    // squad-cli package node_modules
    join(__dirname, '..', 'node_modules', 'ink', 'build', 'ink.js'),
    // Workspace root node_modules (common with npm workspaces)
    join(__dirname, '..', '..', '..', 'node_modules', 'ink', 'build', 'ink.js'),
    // Global install location (node_modules at parent of package)
    join(__dirname, '..', '..', 'ink', 'build', 'ink.js'),
  ];

  const inkJsPath = possiblePaths.find(p => existsSync(p));

  if (!inkJsPath) {
    // ink not installed yet — exit silently
    return false;
  }

  try {
    let content = readFileSync(inkJsPath, 'utf8');
    let patchCount = 0;

    // --- Patch 1: Remove trailing newline ---
    // ink 7.x: const outputToRender = isFullscreen ? output : output + '\n';
    // Patched:  const outputToRender = output;
    //
    // The search string below is a JS double-quoted string where '\\n' represents
    // the two-character sequence backslash + n as it appears in the ink.js source
    // (i.e. the JS string literal '\n' denoting a newline, not an actual newline char).
    const trailingNewlineSearch = "const outputToRender = isFullscreen ? output : output + '\\n';";
    const trailingNewlineReplace = 'const outputToRender = output;';
    if (content.includes(trailingNewlineSearch)) {
      content = content.replace(trailingNewlineSearch, trailingNewlineReplace);
      console.log('  ✅ Patch 1/3: Removed trailing newline from outputToRender');
      patchCount++;
    } else if (content.includes(trailingNewlineReplace)) {
      console.log('  ⏭️  Patch 1/3: Trailing newline already removed');
    } else {
      console.warn('  ⚠️  Patch 1/3: Could not find outputToRender pattern — Ink version may have changed');
    }

    // --- Patch 2: Disable clearTerminal shouldClearTerminal path ---
    // ink 7.x: if (shouldClearTerminal) {
    //              const sync = this.shouldSync();
    //              ...
    //              this.options.stdout.write(ansiEscapes.clearTerminal + ...
    // Patched:  if (false) {
    //
    // We match `if (shouldClearTerminal) {` only when followed by
    // `const sync = this.shouldSync` to avoid replacing unrelated references.
    const fullscreenSearch = /if \(shouldClearTerminal\) \{\s*\n\s*const sync = this\.shouldSync/;
    const fullscreenAlreadyPatched = /if \(false\) \{\s*\n\s*const sync = this\.shouldSync/;
    if (fullscreenSearch.test(content)) {
      content = content.replace(
        /if \(shouldClearTerminal\) (\{\s*\n\s*const sync = this\.shouldSync)/,
        'if (false) $1'
      );
      console.log('  ✅ Patch 2/3: Disabled clearTerminal fullscreen path');
      patchCount++;
    } else if (fullscreenAlreadyPatched.test(content)) {
      console.log('  ⏭️  Patch 2/3: clearTerminal path already disabled');
    } else {
      console.warn('  ⚠️  Patch 2/3: Could not find shouldClearTerminal pattern — Ink version may have changed');
    }

    // --- Patch 3: Verify incrementalRendering passthrough ---
    const incrementalPattern = 'incremental: options.incrementalRendering';
    if (content.includes(incrementalPattern)) {
      console.log('  ✅ Patch 3/3: incrementalRendering passthrough verified (no change needed)');
    } else {
      console.warn('  ⚠️  Patch 3/3: incrementalRendering passthrough not found — Ink version may have changed');
    }

    if (patchCount > 0) {
      writeFileSync(inkJsPath, content, 'utf8');
      console.log(`✅ Patched ink.js with ${patchCount} rendering fix(es) for scroll flicker`);
      return true;
    }

    return false;
  } catch (err) {
    console.warn('⚠️  Failed to patch ink.js rendering:', err.message);
    console.warn('    Scroll flicker may occur on Windows Terminal.');
    return false;
  }
}

// Run patch
patchInkRendering();
