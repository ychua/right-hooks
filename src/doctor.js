'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');

function run(args) {
  const rhDir = '.right-hooks';
  let issues = 0;
  let warnings = 0;

  console.log('\n🥊  Right Hooks Doctor\n');

  // Check .right-hooks directory exists
  if (!fs.existsSync(rhDir)) {
    console.error('❌ Right Hooks is not initialized. Run: npx right-hooks init');
    process.exit(1);
  }
  console.log('✓ .right-hooks/ directory exists');

  // Check version file
  const versionFile = path.join(rhDir, 'version');
  if (fs.existsSync(versionFile)) {
    console.log(`✓ Version: ${fs.readFileSync(versionFile, 'utf8').trim()}`);
  } else {
    console.log('⚠ Missing version file');
    warnings++;
  }

  // Check active preset
  const presetFile = path.join(rhDir, 'active-preset.json');
  if (fs.existsSync(presetFile)) {
    try {
      const preset = JSON.parse(fs.readFileSync(presetFile, 'utf8'));
      console.log(`✓ Active preset: ${preset.language}`);
    } catch {
      console.log('❌ active-preset.json is malformed');
      issues++;
    }
  } else {
    console.log('⚠ No active preset configured');
    warnings++;
  }

  // Check hooks exist and are executable
  const hooksDir = path.join(rhDir, 'hooks');
  const expectedHooks = [
    '_preamble.sh', 'pre-merge.sh', 'pre-push-master.sh', 'pre-pr-create.sh',
    'stop-check.sh', 'post-edit-check.sh', 'subagent-stop-check.sh',
    'judge.sh', 'session-start.sh',
  ];

  for (const hook of expectedHooks) {
    const hookPath = path.join(hooksDir, hook);
    if (!fs.existsSync(hookPath)) {
      console.log(`❌ Missing hook: ${hook}`);
      issues++;
    } else {
      const stat = fs.statSync(hookPath);
      if (!(stat.mode & 0o111)) {
        console.log(`⚠ Hook not executable: ${hook}`);
        warnings++;
      }
    }
  }
  if (issues === 0) {
    console.log(`✓ All ${expectedHooks.length} hooks present`);
  }

  // Check checksums
  const checksumFile = path.join(rhDir, '.checksums');
  if (fs.existsSync(checksumFile)) {
    try {
      const checksums = JSON.parse(fs.readFileSync(checksumFile, 'utf8'));
      let modified = 0;
      for (const [file, expected] of Object.entries(checksums)) {
        const hookPath = path.join(hooksDir, file);
        if (fs.existsSync(hookPath)) {
          const content = fs.readFileSync(hookPath);
          const actual = crypto.createHash('sha256').update(content).digest('hex');
          if (actual !== expected) {
            console.log(`⚠ Modified hook: ${file} (checksum mismatch)`);
            modified++;
            warnings++;
          }
        }
      }
      if (modified === 0) {
        console.log('✓ All hook checksums valid');
      }
    } catch {
      console.log('❌ .checksums file is malformed');
      issues++;
    }
  } else {
    console.log('⚠ Missing .checksums file');
    warnings++;
  }

  // Check Claude Code settings
  const settingsFile = path.join('.claude', 'settings.json');
  if (fs.existsSync(settingsFile)) {
    try {
      const settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
      if (settings.hooks) {
        const hookEvents = Object.keys(settings.hooks);
        console.log(`✓ Claude Code settings: ${hookEvents.length} hook events configured`);
      } else {
        console.log('⚠ Claude Code settings.json has no hooks section');
        warnings++;
      }
    } catch {
      console.log('❌ .claude/settings.json is malformed');
      issues++;
    }
  } else {
    console.log('⚠ No .claude/settings.json found');
    warnings++;
  }

  // Check rules symlinks
  const rulesDir = path.join('.claude', 'rules');
  if (fs.existsSync(rulesDir)) {
    const rules = fs.readdirSync(rulesDir).filter(f => f.endsWith('.md'));
    console.log(`✓ ${rules.length} rule files in .claude/rules/`);
  } else {
    console.log('⚠ No .claude/rules/ directory');
    warnings++;
  }

  // Check dependencies
  const deps = ['gh', 'jq', 'git'];
  for (const dep of deps) {
    try {
      execSync(`command -v ${dep}`, { stdio: 'pipe' });
      console.log(`✓ ${dep} available`);
    } catch {
      console.log(`❌ ${dep} not found — hooks require this`);
      issues++;
    }
  }

  // Summary
  console.log(`\n${'─'.repeat(40)}`);
  if (issues === 0 && warnings === 0) {
    console.log('✅ All checks passed. Right Hooks is healthy.\n');
  } else {
    if (issues > 0) console.log(`❌ ${issues} issue(s) found`);
    if (warnings > 0) console.log(`⚠  ${warnings} warning(s)`);
    if (issues > 0) {
      console.log('\nRun `npx right-hooks init` to fix missing files.');
    }
    console.log('');
  }

  process.exit(issues > 0 ? 1 : 0);
}

module.exports = { run };
