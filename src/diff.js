'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function run(args) {
  const rhDir = '.right-hooks';

  if (!fs.existsSync(rhDir)) {
    console.error('❌ Right Hooks is not initialized. Run: npx right-hooks init');
    process.exit(1);
  }

  const pkgRoot = path.resolve(__dirname, '..');
  const pkgVersion = require(path.join(pkgRoot, 'package.json')).version;
  const currentVersion = readFile(path.join(rhDir, 'version')) || '0.0.0';

  console.log(`\n🥊  Right Hooks diff: v${currentVersion} → v${pkgVersion}\n`);

  if (currentVersion === pkgVersion) {
    console.log('Already up to date — no changes to show.\n');
    return;
  }

  // Load installed checksums
  const checksumFile = path.join(rhDir, '.checksums');
  let oldChecksums = {};
  try {
    oldChecksums = JSON.parse(fs.readFileSync(checksumFile, 'utf8'));
  } catch {}

  // Compare hooks
  const pkgHooksDir = path.join(pkgRoot, 'hooks');
  const installedHooksDir = path.join(rhDir, 'hooks');
  const hookFiles = fs.readdirSync(pkgHooksDir).filter(f => f.endsWith('.sh'));

  let updated = 0;
  let preserved = 0;
  let added = 0;
  let unchanged = 0;

  console.log('Hooks:');
  for (const file of hookFiles) {
    const pkgPath = path.join(pkgHooksDir, file);
    const installedPath = path.join(installedHooksDir, file);
    const pkgContent = fs.readFileSync(pkgPath);
    const pkgHash = crypto.createHash('sha256').update(pkgContent).digest('hex');

    if (!fs.existsSync(installedPath)) {
      console.log(`  + ${file} (new — would be added)`);
      added++;
    } else {
      const installedContent = fs.readFileSync(installedPath);
      const installedHash = crypto.createHash('sha256').update(installedContent).digest('hex');
      const expectedHash = oldChecksums[file];

      if (expectedHash && installedHash !== expectedHash) {
        console.log(`  ⊘ ${file} (you modified — would be preserved)`);
        preserved++;
      } else if (installedHash !== pkgHash) {
        console.log(`  ↑ ${file} (would be updated)`);
        updated++;
      } else {
        console.log(`  · ${file} (unchanged)`);
        unchanged++;
      }
    }
  }

  // Check for hooks that exist locally but not in package (orphaned)
  if (fs.existsSync(installedHooksDir)) {
    const installedFiles = fs.readdirSync(installedHooksDir).filter(f => f.endsWith('.sh'));
    const pkgSet = new Set(hookFiles);
    for (const file of installedFiles) {
      if (!pkgSet.has(file)) {
        console.log(`  ? ${file} (local only — not in package)`);
      }
    }
  }

  // Compare rules
  const pkgRulesDir = path.join(pkgRoot, 'rules');
  const installedRulesDir = path.join(rhDir, 'rules');
  if (fs.existsSync(pkgRulesDir)) {
    const ruleFiles = fs.readdirSync(pkgRulesDir).filter(f => f.endsWith('.md'));
    let ruleChanges = 0;
    console.log('\nRules:');
    for (const file of ruleFiles) {
      const pkgPath = path.join(pkgRulesDir, file);
      const installedPath = path.join(installedRulesDir, file);

      if (!fs.existsSync(installedPath)) {
        console.log(`  + ${file} (new)`);
        ruleChanges++;
      } else {
        const pkgContent = fs.readFileSync(pkgPath, 'utf8');
        const installedContent = fs.readFileSync(installedPath, 'utf8');
        if (pkgContent !== installedContent) {
          // Skip learned-patterns.md — always preserved
          if (file === 'learned-patterns.md') {
            console.log(`  ⊘ ${file} (user content — preserved)`);
          } else {
            console.log(`  ↑ ${file} (would be updated)`);
            ruleChanges++;
          }
        } else {
          console.log(`  · ${file} (unchanged)`);
        }
      }
    }
    if (ruleChanges === 0) {
      // Already printed individual statuses
    }
  }

  // Summary
  console.log(`\n${'─'.repeat(40)}`);
  console.log(`  ${updated} would update, ${added} would add, ${preserved} would preserve, ${unchanged} unchanged`);
  if (updated > 0 || added > 0) {
    console.log('\n  Run `npx right-hooks upgrade` to apply changes.\n');
  } else {
    console.log('\n  No updates needed.\n');
  }
}

function readFile(p) {
  try { return fs.readFileSync(p, 'utf8').trim(); } catch { return null; }
}

module.exports = { run };
