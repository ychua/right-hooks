'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const readline = require('readline');
const { detect } = require('./detect');

// Search for a plugin in Claude Code's plugin directories
function findInPlugins(homeDir, name) {
  const pluginsBase = path.join(homeDir, '.claude', 'plugins', 'marketplaces');
  if (!fs.existsSync(pluginsBase)) return false;
  try {
    const marketplaces = fs.readdirSync(pluginsBase);
    for (const mp of marketplaces) {
      // Check marketplaces/{mp}/plugins/{name}/
      const pluginDir = path.join(pluginsBase, mp, 'plugins', name);
      if (fs.existsSync(pluginDir)) return true;
      // Check marketplaces/{mp}/{name}/ (flat layout)
      const flatDir = path.join(pluginsBase, mp, name);
      if (fs.existsSync(flatDir)) return true;
      // Check if marketplace name contains the plugin name
      // e.g. "superpowers-marketplace" contains "superpowers"
      if (mp.includes(name)) return true;
    }
    // Also check the installed plugins cache directory
    const cachePath = path.join(homeDir, '.claude', 'plugins', 'cache', name);
    if (fs.existsSync(cachePath)) return true;
  } catch {}
  return false;
}

const VERSION = require('../package.json').version;
const RH_DIR = '.right-hooks';
const CLAUDE_DIR = '.claude';

// Detect gstack and superpowers installations
function detectTooling(projectDir) {
  const homeDir = require('os').homedir();
  const hasGstack = fs.existsSync(path.join(projectDir, '.claude', 'skills', 'gstack'))
    || fs.existsSync(path.join(homeDir, '.claude', 'skills', 'gstack'))
    || findInPlugins(homeDir, 'gstack');
  const hasSuperpowers = fs.existsSync(path.join(projectDir, '.claude', 'skills', 'superpowers'))
    || fs.existsSync(path.join(homeDir, '.claude', 'skills', 'superpowers'))
    || findInPlugins(homeDir, 'superpowers');

  const gstackLocation = hasGstack
    ? (fs.existsSync(path.join(projectDir, '.claude', 'skills', 'gstack'))
      ? '.claude/skills/gstack/'
      : fs.existsSync(path.join(homeDir, '.claude', 'skills', 'gstack'))
        ? '~/.claude/skills/gstack/'
        : 'Claude Code plugin')
    : null;
  const superpowersLocation = hasSuperpowers
    ? (fs.existsSync(path.join(projectDir, '.claude', 'skills', 'superpowers'))
      ? '.claude/skills/superpowers/'
      : fs.existsSync(path.join(homeDir, '.claude', 'skills', 'superpowers'))
        ? '~/.claude/skills/superpowers/'
        : 'Claude Code plugin')
    : null;

  return { hasGstack, hasSuperpowers, gstackLocation, superpowersLocation };
}

function run(args) {
  const projectDir = process.cwd();
  const pkgRoot = path.resolve(__dirname, '..');

  console.log('\n🥊  Right Hooks — Lifecycle Enforcement for Agentic Software Harness\n');

  // Step 1: Detect project
  console.log('Detecting project...');
  const detection = detect(projectDir);

  if (detection.detected.length === 0) {
    console.log('  ⚠ No specific project type detected');
    console.log('  → Using generic preset (universal hooks only)\n');
  } else {
    for (const d of detection.detected) {
      console.log(`  ✓ ${d.type} (${d.file} found)`);
    }
  }

  // Detect gstack + superpowers early (before profile selection)
  const tooling = detectTooling(projectDir);

  if (tooling.hasGstack) {
    console.log(`  ✓ gstack detected (${tooling.gstackLocation})`);
  }
  if (tooling.hasSuperpowers) {
    console.log(`  ✓ superpowers detected (${tooling.superpowersLocation})`);
  }

  if (detection.detected.length > 0) {
    console.log(`\n  Recommended preset: ${detection.preset}\n`);
  }

  // Non-interactive mode for CI or --yes flag
  const nonInteractive = args.includes('--yes') || args.includes('-y') || !process.stdin.isTTY;
  
  if (nonInteractive) {
    install(projectDir, pkgRoot, detection.preset, 'recommended', tooling);
  } else {
    interactiveSetup(projectDir, pkgRoot, detection.preset, tooling);
  }
}

function interactiveSetup(projectDir, pkgRoot, detectedPreset, tooling) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  const profiles = ['recommended', 'strict', 'light', 'custom'];
  console.log('Select enforcement profile (see README for details):');
  console.log('  1) Recommended (strict for feat/, standard for fix/, light for docs/)');
  console.log('  2) Strict only (full lifecycle for everything)');
  console.log('  3) Light (minimal enforcement)');
  console.log('  4) Custom (toggle individual gates in .right-hooks/active-profile.json)');
  console.log('');
  console.log('  📖 https://github.com/ychua/right-hooks#enforcement-profiles\n');

  rl.question('Choice [1]: ', (answer) => {
    const choice = parseInt(answer) || 1;
    const profile = profiles[choice - 1] || 'recommended';
    rl.close();
    install(projectDir, pkgRoot, detectedPreset, profile, tooling);
  });
}

function install(projectDir, pkgRoot, preset, profileChoice, tooling) {
  const rhDir = path.join(projectDir, RH_DIR);
  const claudeDir = path.join(projectDir, CLAUDE_DIR);

  // Create directories
  const dirs = [
    rhDir,
    path.join(rhDir, 'hooks'),
    path.join(rhDir, 'rules'),
    path.join(rhDir, 'templates'),
    path.join(rhDir, 'presets'),
    path.join(rhDir, 'profiles'),
    path.join(rhDir, '.overrides'),
    path.join(rhDir, '.stats'),
    claudeDir,
    path.join(claudeDir, 'rules'),
  ];
  for (const dir of dirs) {
    fs.mkdirSync(dir, { recursive: true });
  }

  // Copy signatures — use tooling detection results (no re-detection needed)
  const signaturesDir = path.join(pkgRoot, 'signatures');

  const sigSource = tooling.hasGstack ? 'gstack.json' : tooling.hasSuperpowers ? 'superpowers.json' : 'generic.json';
  const sigLabel = tooling.hasGstack ? 'gstack' : tooling.hasSuperpowers ? 'superpowers' : 'generic';

  const sigSrc = path.join(signaturesDir, sigSource);
  const sigDst = path.join(rhDir, 'signatures.json');
  fs.copyFileSync(sigSrc, sigDst);
  console.log(`✓ Signatures configured: ${sigLabel}`);

  // Copy skills config (same detection logic as signatures)
  const skillsSource = tooling.hasGstack ? 'skills-gstack.json'
    : tooling.hasSuperpowers ? 'skills-superpowers.json'
    : 'skills-generic.json';
  const skillsSrc = path.join(signaturesDir, skillsSource);
  const skillsDst = path.join(rhDir, 'skills.json');
  if (fs.existsSync(skillsSrc)) {
    fs.copyFileSync(skillsSrc, skillsDst);
    console.log(`✓ Skills configured: ${skillsSource.replace('skills-', '').replace('.json', '')}`);
  }

  // Copy hooks
  const hooksDir = path.join(pkgRoot, 'hooks');
  const hookFiles = fs.readdirSync(hooksDir).filter(f => f.endsWith('.sh'));
  for (const file of hookFiles) {
    const src = path.join(hooksDir, file);
    const dst = path.join(rhDir, 'hooks', file);
    fs.copyFileSync(src, dst);
    fs.chmodSync(dst, 0o755);
  }
  console.log(`✓ Hooks installed to ${RH_DIR}/hooks/ (${hookFiles.length} hooks)`);

  // Copy agent definitions to .claude/agents/
  const agentsSrcDir = path.join(pkgRoot, 'agents');
  const agentsDstDir = path.join(claudeDir, 'agents');
  if (fs.existsSync(agentsSrcDir)) {
    fs.mkdirSync(agentsDstDir, { recursive: true });
    const agentFiles = fs.readdirSync(agentsSrcDir).filter(f => f.endsWith('.md'));
    for (const file of agentFiles) {
      fs.copyFileSync(path.join(agentsSrcDir, file), path.join(agentsDstDir, file));
    }
    console.log(`✓ Agents installed to ${CLAUDE_DIR}/agents/ (${agentFiles.length} agents)`);
  }

  // Copy rules
  const rulesDir = path.join(pkgRoot, 'rules');
  const ruleFiles = fs.readdirSync(rulesDir).filter(f => f.endsWith('.md'));
  for (const file of ruleFiles) {
    const src = path.join(rulesDir, file);
    const dst = path.join(rhDir, 'rules', file);
    fs.copyFileSync(src, dst);
    // Symlink to .claude/rules/
    const link = path.join(claudeDir, 'rules', file);
    try {
      if (fs.existsSync(link)) fs.unlinkSync(link);
      fs.symlinkSync(path.relative(path.join(claudeDir, 'rules'), dst), link);
    } catch {
      // Fallback: copy instead of symlink (Windows)
      fs.copyFileSync(src, link);
    }
  }
  console.log(`✓ Rules symlinked to ${CLAUDE_DIR}/rules/ (${ruleFiles.length} rule files)`);

  // Copy templates
  const templatesDir = path.join(pkgRoot, 'templates');
  const templateFiles = fs.readdirSync(templatesDir).filter(f => f.endsWith('.md'));
  for (const file of templateFiles) {
    fs.copyFileSync(path.join(templatesDir, file), path.join(rhDir, 'templates', file));
  }
  console.log(`✓ Templates installed to ${RH_DIR}/templates/ (${templateFiles.length} templates)`);

  // Copy presets
  const presetsDir = path.join(pkgRoot, 'presets');
  const presetFiles = fs.readdirSync(presetsDir).filter(f => f.endsWith('.json'));
  for (const file of presetFiles) {
    fs.copyFileSync(path.join(presetsDir, file), path.join(rhDir, 'presets', file));
  }
  // Set active preset
  const activePresetSrc = path.join(presetsDir, `${preset}.json`);
  if (fs.existsSync(activePresetSrc)) {
    fs.copyFileSync(activePresetSrc, path.join(rhDir, 'active-preset.json'));
  }
  console.log(`✓ Preset applied: ${preset}`);

  // Copy profiles
  const profilesDir = path.join(pkgRoot, 'profiles');
  const profileFiles = fs.readdirSync(profilesDir).filter(f => f.endsWith('.json'));
  for (const file of profileFiles) {
    fs.copyFileSync(path.join(profilesDir, file), path.join(rhDir, 'profiles', file));
  }
  // Set active profile
  const activeProfileName = profileChoice === 'strict' ? 'strict' : profileChoice === 'light' ? 'light' : 'standard';
  const activeProfileSrc = path.join(profilesDir, `${activeProfileName}.json`);
  if (fs.existsSync(activeProfileSrc)) {
    fs.copyFileSync(activeProfileSrc, path.join(rhDir, 'active-profile.json'));
  }
  console.log(`✓ Profile applied: ${profileChoice}`);

  // Set up husky
  const huskyDir = path.join(projectDir, '.husky');
  fs.mkdirSync(huskyDir, { recursive: true });
  const huskyFiles = ['pre-push', 'post-merge'];
  const huskySrcDir = path.join(pkgRoot, 'husky');
  for (const file of huskyFiles) {
    const src = path.join(huskySrcDir, file);
    const dst = path.join(huskyDir, file);
    fs.copyFileSync(src, dst);
    fs.chmodSync(dst, 0o755);
  }
  console.log('✓ Husky hooks configured (pre-push + post-merge)');

  // Check if husky is actually installed in the target project
  const huskyInstalled = fs.existsSync(path.join(projectDir, 'node_modules', 'husky'))
    || fs.existsSync(path.join(projectDir, 'node_modules', '.package-lock.json'));
  let huskyInPkg = false;
  try {
    const targetPkg = JSON.parse(fs.readFileSync(path.join(projectDir, 'package.json'), 'utf8'));
    huskyInPkg = !!(targetPkg.devDependencies?.husky || targetPkg.dependencies?.husky);
  } catch {}
  if (!huskyInstalled && !huskyInPkg) {
    console.log('  ⚠ husky not found in this project. Install it: npm install -D husky');
    console.log('  Without husky, git hooks (pre-push, post-merge) will not fire.');
  }

  // Generate checksums
  const checksums = {};
  for (const file of hookFiles) {
    const content = fs.readFileSync(path.join(rhDir, 'hooks', file));
    checksums[file] = crypto.createHash('sha256').update(content).digest('hex');
  }
  fs.writeFileSync(path.join(rhDir, '.checksums'), JSON.stringify(checksums, null, 2));

  // Write version
  fs.writeFileSync(path.join(rhDir, 'version'), VERSION);

  // Update .claude/settings.json
  const settingsSrc = path.join(pkgRoot, 'settings.json');
  const settingsDst = path.join(claudeDir, 'settings.json');
  if (fs.existsSync(settingsSrc)) {
    const { mergeSettings } = require('./settings-merge');
    const shipped = JSON.parse(fs.readFileSync(settingsSrc, 'utf8'));
    let existing = {};
    if (fs.existsSync(settingsDst)) {
      try {
        existing = JSON.parse(fs.readFileSync(settingsDst, 'utf8'));
      } catch {}
    }
    const merged = mergeSettings(existing, shipped);
    fs.writeFileSync(settingsDst, JSON.stringify(merged, null, 2));
  }
  console.log('✓ Claude Code settings.json updated');

  // Create learned-patterns.md
  const learnedPath = path.join(rhDir, 'rules', 'learned-patterns.md');
  if (!fs.existsSync(learnedPath)) {
    fs.writeFileSync(learnedPath, '# Learned Patterns\n\nRules extracted from post-PR learnings. One line per rule, actionable, no context.\n\n');
  }

  // Scaffold docs directories (idempotent — skips existing)
  const { run: scaffold } = require('./scaffold');
  scaffold([]);

  console.log(`
Next steps:
  1. Review ${RH_DIR}/profiles/ and customize thresholds
  2. Commit the ${RH_DIR}/ directory
  3. Start a Claude Code session — hooks are active immediately

Commands:
  npx right-hooks status          Show active profile, preset, and gate status
  npx right-hooks scaffold        Create docs directories
  npx right-hooks preset <name>   Switch language preset
  npx right-hooks profile <name>  Switch enforcement profile
  npx right-hooks doctor          Diagnose hook configuration issues
  npx right-hooks doctor --fix    Auto-repair common issues
  npx right-hooks diff            Preview what upgrade would change
  npx right-hooks override        Override a gate with audited reason
  npx right-hooks upgrade         Upgrade generated hooks (preserves custom hooks)
`);
}

module.exports = { run, detectTooling };
