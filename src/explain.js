'use strict';

const path = require('path');
const {
  getAllGateNames,
  getGateInfo,
  getActiveGates,
  suggestGate,
} = require('./gates');

function run(args) {
  const gateName = args[0];

  if (!gateName) {
    showAllGates();
    return;
  }

  const info = getGateInfo(gateName);
  if (!info) {
    showUnknownGate(gateName);
    return;
  }

  showGateDetail(gateName, info);
}

/**
 * Displays a table of all gates with their enabled/disabled status per profile.
 */
function showAllGates() {
  const profilesDir = path.join('.right-hooks', 'profiles');
  const activeGates = getActiveGates(profilesDir);
  const gateNames = getAllGateNames();

  // Collect profile names from the activeGates data
  const profileNames = new Set();
  for (const gate of gateNames) {
    for (const profile of Object.keys(activeGates[gate])) {
      profileNames.add(profile);
    }
  }
  const profiles = Array.from(profileNames).sort();

  console.log('\nRight Hooks Gates\n');

  if (profiles.length === 0) {
    // No profiles found — show simple list
    for (const gate of gateNames) {
      const info = getGateInfo(gate);
      const tag = info.alwaysOn ? ' (always on)' : '';
      console.log(`  ${gate}${tag}`);
      console.log(`    ${info.description}`);
    }
    console.log(`\nRun 'npx right-hooks explain <gate>' for details on a specific gate.`);
    return;
  }

  // Build table header
  const gateCol = 18;
  const profCol = 10;

  let header = 'Gate'.padEnd(gateCol);
  for (const p of profiles) {
    header += p.padStart(profCol);
  }
  console.log(header);
  console.log('-'.repeat(gateCol + profiles.length * profCol));

  for (const gate of gateNames) {
    let row = gate.padEnd(gateCol);
    for (const p of profiles) {
      const enabled = activeGates[gate][p];
      const icon = enabled ? 'on' : '-';
      row += icon.padStart(profCol);
    }
    console.log(row);
  }

  console.log(`\nRun 'npx right-hooks explain <gate>' for details on a specific gate.`);
}

/**
 * Displays detailed information about a single gate.
 */
function showGateDetail(name, info) {
  console.log(`\nGate: ${name}${info.alwaysOn ? ' (always on)' : ''}\n`);
  console.log(`What it checks:`);
  console.log(`  ${info.description}\n`);
  console.log(`How to satisfy:`);
  console.log(`  ${info.howToSatisfy}\n`);
  console.log(`How to override:`);
  console.log(`  ${info.howToOverride}\n`);
}

/**
 * Shows a helpful error for an unknown gate name, with fuzzy suggestion.
 */
function showUnknownGate(input) {
  const suggestion = suggestGate(input);

  if (suggestion) {
    console.error(`Unknown gate: "${input}". Did you mean "${suggestion}"?\n`);
  } else {
    console.error(`Unknown gate: "${input}".\n`);
  }

  console.error('Available gates:');
  for (const gate of getAllGateNames()) {
    console.error(`  ${gate}`);
  }
}

module.exports = { run };
