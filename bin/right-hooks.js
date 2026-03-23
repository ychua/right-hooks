#!/usr/bin/env node
'use strict';

const path = require('path');
const fs = require('fs');

const VERSION = require('../package.json').version;
const COMMANDS = {
  init: 'Initialize Right Hooks in the current project',
  scaffold: 'Create docs directories (designs, exec-plans, retros)',
  status: 'Show active profile, preset, and gate status',
  preset: 'Switch language preset (e.g., right-hooks preset typescript)',
  profile: 'Switch enforcement profile (e.g., right-hooks profile strict)',
  skills: 'Show or set configured review/QA/doc skills',
  explain: 'Explain what a gate checks and how to fix blocks',
  stats: 'Show gate effectiveness metrics and human involvement',
  doctor: 'Diagnose hook configuration issues (--fix to auto-repair)',
  diff: 'Preview what upgrade would change (read-only)',
  override: 'Override a gate with audited reason',
  overrides: 'List or clear active overrides',
  upgrade: 'Upgrade generated hooks (preserves custom hooks)',
  help: 'Show this help message',
  version: 'Show version',
};

function main() {
  const args = process.argv.slice(2);
  const command = args[0] || 'help';

  switch (command) {
    case 'init':
      require('../src/init.js').run(args.slice(1));
      break;
    case 'scaffold':
      require('../src/scaffold.js').run(args.slice(1));
      break;
    case 'status':
      require('../src/status.js').run(args.slice(1));
      break;
    case 'skills':
      require('../src/skills.js').run(args.slice(1), command);
      break;
    case 'explain':
      require('../src/explain.js').run(args.slice(1));
      break;
    case 'stats':
      require('../src/stats.js').run(args.slice(1));
      break;
    case 'doctor':
      require('../src/doctor.js').run(args.slice(1));
      break;
    case 'diff':
      require('../src/diff.js').run(args.slice(1));
      break;
    case 'override':
    case 'overrides':
      require('../src/override.js').run(args.slice(1), command);
      break;
    case 'upgrade':
      require('../src/upgrade.js').run(args.slice(1));
      break;
    case 'preset': {
      const name = args[1];
      if (!name) {
        console.error('Usage: right-hooks preset <name>');
        console.error('Available: typescript, python, go, rust, generic');
        process.exit(1);
      }
      switchPreset(name);
      break;
    }
    case 'profile': {
      const name = args[1];
      if (!name) {
        console.error('Usage: right-hooks profile <name>');
        console.error('Available: strict, standard, light');
        process.exit(1);
      }
      switchProfile(name);
      break;
    }
    case 'version':
    case '--version':
    case '-v':
      console.log(`right-hooks v${VERSION}`);
      break;
    case 'help':
    case '--help':
    case '-h':
    default:
      showHelp();
      break;
  }
}

function switchPreset(name) {
  const presetPath = path.join('.right-hooks', 'presets', `${name}.json`);
  if (!fs.existsSync(presetPath)) {
    console.error(`❌ Preset "${name}" not found at ${presetPath}`);
    process.exit(1);
  }
  const preset = fs.readFileSync(presetPath, 'utf8');
  fs.writeFileSync(path.join('.right-hooks', 'active-preset.json'), preset);
  console.log(`✓ Preset switched to: ${name}`);
}

function switchProfile(name) {
  const profilePath = path.join('.right-hooks', 'profiles', `${name}.json`);
  if (!fs.existsSync(profilePath)) {
    console.error(`❌ Profile "${name}" not found at ${profilePath}`);
    process.exit(1);
  }
  const profile = fs.readFileSync(profilePath, 'utf8');
  fs.writeFileSync(path.join('.right-hooks', 'active-profile.json'), profile);
  console.log(`✓ Profile switched to: ${name}`);
}

function showHelp() {
  console.log(`
🥊  Right Hooks v${VERSION} — Lifecycle Enforcement for Agentic Software Harness

Usage: right-hooks <command> [options]

Commands:`);
  for (const [cmd, desc] of Object.entries(COMMANDS)) {
    console.log(`  ${cmd.padEnd(12)} ${desc}`);
  }
  console.log(`
Examples:
  npx right-hooks init                    Initialize Right Hooks in current project
  npx right-hooks scaffold                Create docs directories
  npx right-hooks status                  Show enforcement status
  npx right-hooks preset typescript       Switch to TypeScript preset
  npx right-hooks profile strict          Switch to strict enforcement
  npx right-hooks doctor                  Check hook health
  npx right-hooks doctor --fix            Auto-repair common issues
  npx right-hooks explain ci               Explain what a gate checks
  npx right-hooks stats                   Show gate effectiveness metrics
  npx right-hooks diff                    Preview what upgrade would change
  npx right-hooks override --gate=qa \\
    --reason="Manual testing done"  Override a gate
  npx right-hooks upgrade                 Upgrade to latest hooks
`);
}

main();
