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

  console.log(`\n🥊  Right Hooks upgrade: v${currentVersion} → v${pkgVersion}\n`);

  if (currentVersion === pkgVersion) {
    console.log('Already up to date.\n');
    return;
  }

  // Load existing checksums
  const checksumFile = path.join(rhDir, '.checksums');
  let oldChecksums = {};
  try {
    oldChecksums = JSON.parse(fs.readFileSync(checksumFile, 'utf8'));
  } catch {}

  // Upgrade hooks
  const hooksDir = path.join(pkgRoot, 'hooks');
  const hookFiles = fs.readdirSync(hooksDir).filter(f => f.endsWith('.sh'));
  const newChecksums = {};
  let updated = 0;
  let preserved = 0;
  let added = 0;

  for (const file of hookFiles) {
    const src = path.join(hooksDir, file);
    const dst = path.join(rhDir, 'hooks', file);
    const srcContent = fs.readFileSync(src);
    const srcHash = crypto.createHash('sha256').update(srcContent).digest('hex');
    newChecksums[file] = srcHash;

    if (!fs.existsSync(dst)) {
      // New hook
      fs.copyFileSync(src, dst);
      fs.chmodSync(dst, 0o755);
      console.log(`  ✓ ${file} — new hook (added)`);
      added++;
    } else {
      const dstContent = fs.readFileSync(dst);
      const dstHash = crypto.createHash('sha256').update(dstContent).digest('hex');
      const expectedHash = oldChecksums[file];

      if (expectedHash && dstHash !== expectedHash) {
        // User modified this hook — preserve it
        console.log(`  ⊘ ${file} — you modified this file (preserved)`);
        newChecksums[file] = dstHash; // Keep their version's hash
        preserved++;
      } else if (dstHash !== srcHash) {
        // Generated hook, safe to update
        fs.copyFileSync(src, dst);
        fs.chmodSync(dst, 0o755);
        console.log(`  ✓ ${file} — updated`);
        updated++;
      } else {
        console.log(`  ✓ ${file} — no changes`);
      }
    }
  }

  // Update checksums and version
  fs.writeFileSync(checksumFile, JSON.stringify(newChecksums, null, 2));
  fs.writeFileSync(path.join(rhDir, 'version'), pkgVersion);

  // Upgrade rules
  const rulesDir = path.join(pkgRoot, 'rules');
  if (fs.existsSync(rulesDir)) {
    const ruleFiles = fs.readdirSync(rulesDir).filter(f => f.endsWith('.md'));
    for (const file of ruleFiles) {
      const dst = path.join(rhDir, 'rules', file);
      // Don't overwrite learned-patterns.md
      if (file === 'learned-patterns.md' && fs.existsSync(dst)) {
        console.log(`  ✓ ${file} — preserved (user content)`);
      } else {
        fs.copyFileSync(path.join(rulesDir, file), dst);
      }
    }
  }

  // Skills config — always preserve if exists, generate if missing
  const skillsDst = path.join(rhDir, 'skills.json');
  if (fs.existsSync(skillsDst)) {
    console.log('  ✓ skills.json — preserved (user config)');
  } else {
    // Detect tooling and generate default
    const { detectTooling } = require('./init');
    const tooling = detectTooling(process.cwd());
    const sigDir = path.join(pkgRoot, 'signatures');
    const skillsSource = tooling.hasGstack ? 'skills-gstack.json'
      : tooling.hasSuperpowers ? 'skills-superpowers.json'
      : 'skills-generic.json';
    const skillsSrc = path.join(sigDir, skillsSource);
    if (fs.existsSync(skillsSrc)) {
      fs.copyFileSync(skillsSrc, skillsDst);
      console.log(`  + skills.json — generated (${skillsSource.replace('skills-', '').replace('.json', '')})`);
    }
  }

  console.log(`\nUpgrade complete: ${updated} updated, ${added} added, ${preserved} preserved`);
  console.log("Run 'npx right-hooks doctor' to verify.\n");
}

function readFile(p) {
  try { return fs.readFileSync(p, 'utf8').trim(); } catch { return null; }
}

module.exports = { run };
