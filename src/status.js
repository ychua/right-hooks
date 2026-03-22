'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

function run(args) {
  const rhDir = '.right-hooks';

  if (!fs.existsSync(rhDir)) {
    console.error('❌ Right Hooks is not initialized in this project. Run: npx right-hooks init');
    process.exit(1);
  }

  console.log('\n🥊  Right Hooks Status\n');

  // Version
  const version = readFile(path.join(rhDir, 'version')) || 'unknown';
  console.log(`Version: ${version}`);

  // Active preset
  const preset = readJson(path.join(rhDir, 'active-preset.json'));
  console.log(`Preset:  ${preset?.language || 'none'}`);

  // Active profile
  const profile = readJson(path.join(rhDir, 'active-profile.json'));
  console.log(`Profile: ${profile?.name || 'none'}`);

  // Hook count
  const hooksDir = path.join(rhDir, 'hooks');
  if (fs.existsSync(hooksDir)) {
    const hooks = fs.readdirSync(hooksDir).filter(f => f.endsWith('.sh'));
    console.log(`Hooks:   ${hooks.length} installed`);
  }

  // Overrides
  const overridesDir = path.join(rhDir, '.overrides');
  if (fs.existsSync(overridesDir)) {
    const overrides = fs.readdirSync(overridesDir).filter(f => f.endsWith('.json'));
    if (overrides.length > 0) {
      console.log(`\n⚠ Active overrides: ${overrides.length}`);
      for (const file of overrides) {
        const o = readJson(path.join(overridesDir, file));
        if (o) {
          console.log(`  - ${o.gate} (PR #${o.pr}): ${o.reason}`);
        }
      }
    }
  }

  // Current branch + PR status
  console.log('');
  try {
    const branch = execSync('git branch --show-current', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
    console.log(`Branch:  ${branch}`);

    const prJson = execSync(`gh pr list --head "${branch}" --state open --json number,title --jq '.[0]'`, {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
    }).trim();
    if (prJson) {
      const pr = JSON.parse(prJson);
      console.log(`PR:      #${pr.number} — ${pr.title}`);
    } else {
      console.log('PR:      No open PR');
    }
  } catch {
    console.log('Branch:  (not a git repo or git not available)');
  }

  // Gate status from profile
  if (profile?.gates) {
    console.log('\nGates:');
    for (const [gate, enabled] of Object.entries(profile.gates)) {
      const icon = enabled ? '✓' : '○';
      console.log(`  ${icon} ${gate}`);
    }
  }

  console.log('');
}

function readFile(p) {
  try { return fs.readFileSync(p, 'utf8').trim(); } catch { return null; }
}

function readJson(p) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return null; }
}

module.exports = { run };
