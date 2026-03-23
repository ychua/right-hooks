'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');

function run(args) {
  const rhDir = '.right-hooks';
  const fixing = args.includes('--fix');
  let issues = 0;
  let warnings = 0;
  let fixed = 0;

  console.log(`\n🥊  Right Hooks Doctor${fixing ? ' (--fix mode)' : ''}\n`);

  // Check .right-hooks directory exists
  if (!fs.existsSync(rhDir)) {
    console.error('❌ Right Hooks is not initialized. Run: npx right-hooks init');
    process.exit(1);
  }
  console.log('✓ .right-hooks/ directory exists');

  const pkgRoot = path.resolve(__dirname, '..');
  const pkgVersion = require(path.join(pkgRoot, 'package.json')).version;

  // Check version file
  const versionFile = path.join(rhDir, 'version');
  if (fs.existsSync(versionFile)) {
    console.log(`✓ Version: ${fs.readFileSync(versionFile, 'utf8').trim()}`);
  } else {
    if (fixing) {
      fs.writeFileSync(versionFile, pkgVersion);
      console.log(`🔧 Created version file (${pkgVersion})`);
      fixed++;
    } else {
      console.log('⚠ Missing version file');
      warnings++;
    }
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
    '_preamble.sh', 'block-agent-override.sh', 'pre-merge.sh', 'pre-push-master.sh',
    'pre-pr-create.sh', 'stop-check.sh', 'post-edit-check.sh', 'subagent-stop-check.sh',
    'judge.sh', 'session-start.sh', 'workflow-orchestrator.sh', 'inject-skill.sh',
  ];

  const pkgHooksDir = path.join(pkgRoot, 'hooks');
  let hookIssues = 0;
  for (const hook of expectedHooks) {
    const hookPath = path.join(hooksDir, hook);
    if (!fs.existsSync(hookPath)) {
      if (fixing) {
        const pkgHook = path.join(pkgHooksDir, hook);
        if (fs.existsSync(pkgHook)) {
          fs.mkdirSync(hooksDir, { recursive: true });
          fs.copyFileSync(pkgHook, hookPath);
          fs.chmodSync(hookPath, 0o755);
          console.log(`🔧 Restored missing hook: ${hook}`);
          fixed++;
        } else {
          console.log(`❌ Missing hook: ${hook} (not in package — cannot fix)`);
          issues++;
          hookIssues++;
        }
      } else {
        console.log(`❌ Missing hook: ${hook}`);
        issues++;
        hookIssues++;
      }
    } else {
      const stat = fs.statSync(hookPath);
      if (!(stat.mode & 0o111)) {
        if (fixing) {
          fs.chmodSync(hookPath, 0o755);
          console.log(`🔧 Fixed permissions: ${hook}`);
          fixed++;
        } else {
          console.log(`⚠ Hook not executable: ${hook}`);
          warnings++;
        }
      }
    }
  }
  if (hookIssues === 0 && !fixing) {
    console.log(`✓ All ${expectedHooks.length} hooks present`);
  } else if (fixing) {
    console.log(`✓ All ${expectedHooks.length} hooks verified`);
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
    if (fixing) {
      const checksums = regenerateChecksums(hooksDir, expectedHooks);
      fs.writeFileSync(checksumFile, JSON.stringify(checksums, null, 2));
      console.log('🔧 Regenerated .checksums file');
      fixed++;
    } else {
      console.log('⚠ Missing .checksums file');
      warnings++;
    }
  }

  // Check Claude Code settings (existence + completeness)
  const settingsFile = path.join('.claude', 'settings.json');
  const shippedSettingsFile = path.join(pkgRoot, 'settings.json');
  if (fs.existsSync(settingsFile)) {
    try {
      const settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
      if (settings.hooks) {
        const hookEvents = Object.keys(settings.hooks);
        console.log(`✓ Claude Code settings: ${hookEvents.length} hook events configured`);

        // Verify completeness against shipped settings
        const completenessResult = checkSettingsCompleteness(
          settings, shippedSettingsFile, fixing
        );
        issues += completenessResult.issues;
        warnings += completenessResult.warnings;
        fixed += completenessResult.fixed;

        // In --fix mode, write the merged settings back
        if (fixing && completenessResult.merged) {
          fs.writeFileSync(settingsFile, JSON.stringify(completenessResult.merged, null, 2));
        }
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
    let brokenLinks = 0;
    for (const rule of rules) {
      const linkPath = path.join(rulesDir, rule);
      try {
        const stat = fs.lstatSync(linkPath);
        if (stat.isSymbolicLink()) {
          // Check if target exists
          try {
            fs.readFileSync(linkPath);
          } catch {
            if (fixing) {
              const target = path.join(rhDir, 'rules', rule);
              if (fs.existsSync(target)) {
                fs.unlinkSync(linkPath);
                fs.symlinkSync(path.relative(rulesDir, target), linkPath);
                console.log(`🔧 Fixed broken symlink: ${rule}`);
                fixed++;
              }
            } else {
              console.log(`⚠ Broken symlink: .claude/rules/${rule}`);
              brokenLinks++;
              warnings++;
            }
          }
        }
      } catch {}
    }
    if (brokenLinks === 0) {
      console.log(`✓ ${rules.length} rule files in .claude/rules/`);
    }
  } else {
    if (fixing) {
      fs.mkdirSync(rulesDir, { recursive: true });
      const rhRulesDir = path.join(rhDir, 'rules');
      if (fs.existsSync(rhRulesDir)) {
        const ruleFiles = fs.readdirSync(rhRulesDir).filter(f => f.endsWith('.md'));
        for (const file of ruleFiles) {
          const target = path.join(rhRulesDir, file);
          const link = path.join(rulesDir, file);
          try {
            fs.symlinkSync(path.relative(rulesDir, target), link);
          } catch {
            fs.copyFileSync(target, link);
          }
        }
        console.log(`🔧 Re-created .claude/rules/ with ${ruleFiles.length} symlinks`);
        fixed++;
      }
    } else {
      console.log('⚠ No .claude/rules/ directory');
      warnings++;
    }
  }

  // Check skills config
  const skillsFile = path.join(rhDir, 'skills.json');
  if (fs.existsSync(skillsFile)) {
    try {
      const skills = JSON.parse(fs.readFileSync(skillsFile, 'utf8'));
      const { checkProvider, VALID_GATES } = require('./skills');
      let skillWarnings = 0;
      for (const gate of VALID_GATES) {
        const entry = skills[gate];
        if (entry && entry.provider && !checkProvider(entry.provider)) {
          console.log(`⚠ Skills: ${gate} requires ${entry.provider} but it's not installed`);
          skillWarnings++;
          warnings++;
        }
      }
      if (skillWarnings === 0) {
        console.log(`✓ Skills config valid (${VALID_GATES.length} gates)`);
      }
    } catch {
      console.log('❌ skills.json is malformed');
      issues++;
    }
  } else {
    if (fixing) {
      // Generate default skills.json from tooling detection
      const sigDir = path.join(pkgRoot, 'signatures');
      const { detectTooling } = require('./init');
      const tooling = detectTooling(process.cwd());
      const skillsSource = tooling.hasGstack ? 'skills-gstack.json'
        : tooling.hasSuperpowers ? 'skills-superpowers.json'
        : 'skills-generic.json';
      const skillsSrc = path.join(sigDir, skillsSource);
      if (fs.existsSync(skillsSrc)) {
        fs.copyFileSync(skillsSrc, path.join(rhDir, 'skills.json'));
        console.log(`🔧 Generated skills.json (${skillsSource.replace('skills-', '').replace('.json', '')})`);
        fixed++;
      }
    } else {
      console.log('⚠ No skills.json found (hooks will use runtime detection fallback)');
      warnings++;
    }
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
  if (issues === 0 && warnings === 0 && fixed === 0) {
    console.log('✅ All checks passed. Right Hooks is healthy.\n');
  } else {
    if (fixed > 0) console.log(`🔧 ${fixed} issue(s) auto-fixed`);
    if (issues > 0) console.log(`❌ ${issues} issue(s) found`);
    if (warnings > 0) console.log(`⚠  ${warnings} warning(s)`);
    if (issues > 0 && !fixing) {
      console.log('\nRun `npx right-hooks doctor --fix` to auto-repair.');
    }
    console.log('');
  }

  process.exit(issues > 0 ? 1 : 0);
}

function regenerateChecksums(hooksDir, hookNames) {
  const checksums = {};
  for (const file of hookNames) {
    const hookPath = path.join(hooksDir, file);
    if (fs.existsSync(hookPath)) {
      const content = fs.readFileSync(hookPath);
      checksums[file] = crypto.createHash('sha256').update(content).digest('hex');
    }
  }
  return checksums;
}

/**
 * Compare installed settings.json against shipped settings.json for completeness.
 * Reports missing hook event registrations and missing commands within events.
 * In --fix mode, returns the merged result using the shared mergeSettings helper.
 */
function checkSettingsCompleteness(installed, shippedPath, fixing) {
  const result = { issues: 0, warnings: 0, fixed: 0, merged: null };

  if (!fs.existsSync(shippedPath)) {
    return result;
  }

  let shipped;
  try {
    shipped = JSON.parse(fs.readFileSync(shippedPath, 'utf8'));
  } catch {
    return result;
  }

  if (!shipped.hooks) {
    return result;
  }

  const installedHooks = installed.hooks || {};
  let missingCount = 0;

  for (const [event, entries] of Object.entries(shipped.hooks)) {
    if (!installedHooks[event]) {
      missingCount++;
      if (fixing) {
        console.log(`🔧 Added missing hook registration: ${event}`);
        result.fixed++;
      } else {
        console.log(`⚠ Missing hook registration: ${event}`);
        result.warnings++;
      }
    } else {
      // Check for missing commands within this event
      const installedCmds = new Set(
        installedHooks[event].flatMap(e => (e.hooks || []).map(h => h.command))
      );
      for (const entry of entries) {
        for (const hook of (entry.hooks || [])) {
          if (!installedCmds.has(hook.command)) {
            missingCount++;
            const shortCmd = hook.command.split('/').pop();
            if (fixing) {
              console.log(`🔧 Added missing command in ${event}: ${shortCmd}`);
              result.fixed++;
            } else {
              console.log(`⚠ Missing command in ${event}: ${shortCmd}`);
              result.warnings++;
            }
          }
        }
      }
    }
  }

  if (fixing && missingCount > 0) {
    const { mergeSettings } = require('./settings-merge');
    result.merged = mergeSettings(installed, shipped);
  }

  if (missingCount === 0) {
    console.log('✓ All hook registrations present in settings.json');
  }

  return result;
}

module.exports = { run };
