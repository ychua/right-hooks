'use strict';

const fs = require('fs');
const path = require('path');

/**
 * Central gate registry — single source of truth for all gate metadata.
 * Each gate has a description, how to satisfy it, how to override it,
 * and whether it's always-on (ignores profile settings).
 */
const GATE_REGISTRY = {
  ci: {
    description: 'All CI checks must be green before merge.',
    howToSatisfy: 'Push code and wait for all GitHub Actions / CI checks to pass. Fix any failing checks.',
    howToOverride: 'Cannot be overridden. CI is always enforced.',
    alwaysOn: true,
  },
  dod: {
    description: 'All Definition of Done checklist items in the PR body must be checked.',
    howToSatisfy: 'Check every "- [ ]" item in your PR description. If an item is not applicable, remove it or mark it done with a note.',
    howToOverride: 'npx right-hooks override --gate=dod --reason="<your reason>"',
    alwaysOn: false,
  },
  docConsistency: {
    description: 'A documentation review comment must exist on the PR, matching the configured skill signature.',
    howToSatisfy: 'Dispatch the doc-reviewer agent to check documentation consistency. The comment must match the configured signature pattern.',
    howToOverride: 'Cannot be overridden. Doc consistency is always enforced.',
    alwaysOn: true,
  },
  planningArtifacts: {
    description: 'A design doc and execution plan must be included in the PR diff (feat/ branches only).',
    howToSatisfy: 'Add docs/designs/<feature>.md and docs/exec-plans/<feature>.md to your PR. Use the templates in .right-hooks/templates/.',
    howToOverride: 'npx right-hooks override --gate=planningArtifacts --reason="<your reason>"',
    alwaysOn: false,
  },
  engReview: {
    description: 'An engineering review must be completed before merge.',
    howToSatisfy: 'Request an engineering review from a team member or dispatch a review agent.',
    howToOverride: 'npx right-hooks override --gate=engReview --reason="<your reason>"',
    alwaysOn: false,
  },
  codeReview: {
    description: 'A code review comment with severity markers (CRITICAL/HIGH/MEDIUM/LOW) must exist on the PR.',
    howToSatisfy: 'Dispatch the code-reviewer agent (or use the configured review skill). The comment must include severity markers and match the skill signature.',
    howToOverride: 'npx right-hooks override --gate=codeReview --reason="<your reason>"',
    alwaysOn: false,
  },
  qa: {
    description: 'A QA comment with test result markers must exist on the PR.',
    howToSatisfy: 'Dispatch the QA agent (or use the configured QA skill). The comment must include test result markers and match the skill signature.',
    howToOverride: 'npx right-hooks override --gate=qa --reason="<your reason>"',
    alwaysOn: false,
  },
  learnings: {
    description: 'A learnings document with agent sections and "Rules to Extract" must be in the PR diff.',
    howToSatisfy: 'Add docs/retros/<feature>-learnings.md with ## Review, ## QA sections, and a ### Rules to Extract section containing at least one "- ..." rule.',
    howToOverride: 'npx right-hooks override --gate=learnings --reason="<your reason>"',
    alwaysOn: false,
  },
  stopHook: {
    description: 'The stop hook verifies that review and QA comments exist before the agent session ends.',
    howToSatisfy: 'Ensure both a code review comment and a QA comment exist on the PR before stopping. The stop hook checks for these automatically.',
    howToOverride: 'npx right-hooks override --gate=stopHook --reason="<your reason>"',
    alwaysOn: false,
  },
  postEditCheck: {
    description: 'Post-edit validation runs the type checker after every file edit (based on active preset).',
    howToSatisfy: 'Fix any type errors or lint issues reported after editing files. The checker runs automatically based on your active preset (e.g., tsc for TypeScript).',
    howToOverride: 'npx right-hooks override --gate=postEditCheck --reason="<your reason>"',
    alwaysOn: false,
  },
};

/**
 * Returns an array of all gate names in the registry.
 */
function getAllGateNames() {
  return Object.keys(GATE_REGISTRY);
}

/**
 * Returns the gate info object for a given gate name, or null if not found.
 */
function getGateInfo(name) {
  return GATE_REGISTRY[name] || null;
}

/**
 * Returns an object mapping gate names to their enabled/disabled status
 * across all profiles found in the given profiles directory.
 *
 * Shape: { gateName: { profileName: true|false, ... }, ... }
 */
function getActiveGates(profilesDir) {
  const result = {};
  for (const gate of getAllGateNames()) {
    result[gate] = {};
  }

  if (!fs.existsSync(profilesDir)) {
    return result;
  }

  const files = fs.readdirSync(profilesDir).filter(f => f.endsWith('.json'));
  for (const file of files) {
    try {
      const profile = JSON.parse(fs.readFileSync(path.join(profilesDir, file), 'utf8'));
      const profileName = profile.name || file.replace('.json', '');
      for (const gate of getAllGateNames()) {
        const info = GATE_REGISTRY[gate];
        if (info.alwaysOn) {
          result[gate][profileName] = true;
        } else if (profile.gates && gate in profile.gates) {
          result[gate][profileName] = profile.gates[gate];
        } else {
          result[gate][profileName] = false;
        }
      }
    } catch {
      // Skip malformed profile files
    }
  }

  return result;
}

/**
 * Validates that every gate referenced in profile files exists in the registry.
 * Returns an array of warning strings (empty if everything is valid).
 */
function validateRegistry(profilesDir) {
  const warnings = [];
  const knownGates = new Set(getAllGateNames());

  const dir = profilesDir || path.join('.right-hooks', 'profiles');
  if (!fs.existsSync(dir)) {
    return warnings;
  }

  const files = fs.readdirSync(dir).filter(f => f.endsWith('.json'));
  for (const file of files) {
    try {
      const profile = JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8'));
      if (profile.gates) {
        for (const gate of Object.keys(profile.gates)) {
          if (!knownGates.has(gate)) {
            const suggestion = suggestGate(gate);
            const hint = suggestion ? ` (did you mean "${suggestion}"?)` : '';
            warnings.push(`Profile "${file}": unknown gate "${gate}"${hint}`);
          }
        }
      }
    } catch {
      warnings.push(`Profile "${file}": failed to parse JSON`);
    }
  }

  return warnings;
}

/**
 * Computes the Levenshtein distance between two strings.
 */
function levenshtein(a, b) {
  const m = a.length;
  const n = b.length;

  // Use two rows instead of full matrix for space efficiency
  let prev = Array.from({ length: n + 1 }, (_, i) => i);
  let curr = new Array(n + 1);

  for (let i = 1; i <= m; i++) {
    curr[0] = i;
    for (let j = 1; j <= n; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      curr[j] = Math.min(
        prev[j] + 1,       // deletion
        curr[j - 1] + 1,   // insertion
        prev[j - 1] + cost  // substitution
      );
    }
    // Swap rows (create new array to maintain immutability of prev reference)
    const temp = prev;
    prev = curr;
    curr = temp;
  }

  return prev[n];
}

/**
 * Suggests the closest gate name for a misspelled input.
 * Returns the closest match within Levenshtein distance 3, or null.
 */
function suggestGate(input) {
  const names = getAllGateNames();
  let bestName = null;
  let bestDist = 4; // threshold + 1

  for (const name of names) {
    const dist = levenshtein(input.toLowerCase(), name.toLowerCase());
    if (dist < bestDist) {
      bestDist = dist;
      bestName = name;
    }
  }

  return bestName;
}

module.exports = {
  GATE_REGISTRY,
  getAllGateNames,
  getGateInfo,
  getActiveGates,
  validateRegistry,
  suggestGate,
  levenshtein,
};
