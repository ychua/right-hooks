'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

const SKILLS_PATH = path.join('.right-hooks', 'skills.json');
const VALID_GATES = ['codeReview', 'qa', 'docConsistency'];

function run(args, command) {
  if (command === 'skills' && args[0] === 'set') {
    return setSkill(args.slice(1));
  }
  return showStatus();
}

function showStatus() {
  if (!fs.existsSync(SKILLS_PATH)) {
    console.log('\n🥊  Right Hooks — Skills\n');
    console.log('  ⚠ No skills.json found. Run: npx right-hooks init\n');
    return;
  }

  let skills;
  try {
    skills = JSON.parse(fs.readFileSync(SKILLS_PATH, 'utf8'));
  } catch {
    console.error('❌ skills.json is malformed JSON');
    process.exit(1);
  }

  console.log('\n🥊  Right Hooks — Skills\n');
  console.log('  Gate            Skill                              Provider      Status');
  console.log('  ' + '─'.repeat(76));

  for (const gate of VALID_GATES) {
    const entry = skills[gate] || {};
    const skill = entry.skill || '(prompt-based)';
    const provider = entry.provider || '—';
    const available = checkProvider(entry.provider);
    const status = entry.skill
      ? (available ? '✓ available' : `⚠ ${entry.provider} not found`)
      : '✓ fallback';

    console.log(
      `  ${gate.padEnd(16)}${skill.padEnd(35)}${provider.padEnd(14)}${status}`
    );
  }
  console.log('');
}

function setSkill(args) {
  const gate = args[0];
  const skill = args[1];

  if (!gate || !skill) {
    console.error('Usage: right-hooks skills set <gate> <skill>');
    console.error(`Valid gates: ${VALID_GATES.join(', ')}`);
    process.exit(1);
  }

  if (!VALID_GATES.includes(gate)) {
    console.error(`❌ Unknown gate: "${gate}"`);
    console.error(`Valid gates: ${VALID_GATES.join(', ')}`);
    process.exit(1);
  }

  // Load existing or create new
  let skills = {};
  if (fs.existsSync(SKILLS_PATH)) {
    try {
      skills = JSON.parse(fs.readFileSync(SKILLS_PATH, 'utf8'));
    } catch {
      console.error('❌ skills.json is malformed — creating fresh');
      skills = {};
    }
  }

  // Infer provider from skill prefix
  let provider = null;
  if (skill.startsWith('/')) {
    provider = 'gstack';
  } else if (skill.startsWith('superpowers:')) {
    provider = 'superpowers';
  }

  // Update the gate — spread existing to preserve agentTypes, skillSignature, etc.
  const existing = skills[gate] || {};
  skills[gate] = {
    ...existing,
    skill,
    provider,
    fallback: existing.fallback || `Post a ${gate} comment on the PR`,
  };

  // Atomic write: write to temp, rename
  const tmpPath = path.join('.right-hooks', '.skills.json.tmp');
  fs.mkdirSync(path.dirname(tmpPath), { recursive: true });
  fs.writeFileSync(tmpPath, JSON.stringify(skills, null, 2) + '\n');
  fs.renameSync(tmpPath, SKILLS_PATH);

  console.log(`✓ ${gate} skill set to: ${skill} (provider: ${provider || 'none'})`);
}

function checkProvider(provider) {
  if (!provider) return true; // null provider = prompt-based, always available
  const homeDir = os.homedir();
  switch (provider) {
    case 'gstack':
      return fs.existsSync(path.join('.claude', 'skills', 'gstack'))
        || fs.existsSync(path.join(homeDir, '.claude', 'skills', 'gstack'));
    case 'superpowers':
      return fs.existsSync(path.join('.claude', 'skills', 'superpowers'))
        || fs.existsSync(path.join(homeDir, '.claude', 'skills', 'superpowers'));
    default:
      return true; // Unknown provider — assume available
  }
}

module.exports = { run, checkProvider, VALID_GATES };
