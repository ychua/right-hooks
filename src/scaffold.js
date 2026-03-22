'use strict';

const fs = require('fs');
const path = require('path');

const DOCS_DIRS = [
  'docs/designs',
  'docs/exec-plans',
  'docs/retros',
];

const LEARNED_PATTERNS_PATH = path.join('.right-hooks', 'rules', 'learned-patterns.md');
const LEARNED_PATTERNS_CONTENT = '# Learned Patterns\n\nRules extracted from post-PR learnings. One line per rule, actionable, no context.\n\n';

function run(args) {
  const projectDir = process.cwd();
  let created = 0;
  let existed = 0;

  console.log('\n🥊  Right Hooks — Scaffold\n');

  // Create docs directories with .gitkeep
  for (const dir of DOCS_DIRS) {
    const fullDir = path.join(projectDir, dir);
    const gitkeep = path.join(fullDir, '.gitkeep');

    if (fs.existsSync(fullDir)) {
      console.log(`  ✓ ${dir}/ (already exists)`);
      existed++;
    } else {
      fs.mkdirSync(fullDir, { recursive: true });
      fs.writeFileSync(gitkeep, '');
      console.log(`  + ${dir}/ (created)`);
      created++;
    }
  }

  // Create learned-patterns.md if missing
  const learnedPath = path.join(projectDir, LEARNED_PATTERNS_PATH);
  if (fs.existsSync(learnedPath)) {
    console.log(`  ✓ ${LEARNED_PATTERNS_PATH} (already exists)`);
    existed++;
  } else {
    const learnedDir = path.dirname(learnedPath);
    if (!fs.existsSync(learnedDir)) {
      fs.mkdirSync(learnedDir, { recursive: true });
    }
    fs.writeFileSync(learnedPath, LEARNED_PATTERNS_CONTENT);
    console.log(`  + ${LEARNED_PATTERNS_PATH} (created)`);
    created++;
  }

  console.log(`\n  ${created} created, ${existed} already existed\n`);
}

module.exports = { run };
