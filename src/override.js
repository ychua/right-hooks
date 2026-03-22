'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

function run(args, command) {
  const rhDir = '.right-hooks';
  const overridesDir = path.join(rhDir, '.overrides');

  if (!fs.existsSync(rhDir)) {
    console.error('❌ Right Hooks is not initialized. Run: npx right-hooks init');
    process.exit(1);
  }

  fs.mkdirSync(overridesDir, { recursive: true });

  // List overrides
  if (command === 'overrides') {
    if (args.includes('--clear')) {
      const files = fs.readdirSync(overridesDir).filter(f => f.endsWith('.json'));
      for (const file of files) {
        fs.unlinkSync(path.join(overridesDir, file));
      }
      console.log(`✓ Cleared ${files.length} override(s)`);
      return;
    }

    const files = fs.readdirSync(overridesDir).filter(f => f.endsWith('.json'));
    if (files.length === 0) {
      console.log('No active overrides.');
      return;
    }
    console.log(`\n🥊  Active Overrides (${files.length}):\n`);
    for (const file of files) {
      const o = JSON.parse(fs.readFileSync(path.join(overridesDir, file), 'utf8'));
      console.log(`  Gate:   ${o.gate}`);
      console.log(`  PR:     #${o.pr}`);
      console.log(`  Reason: ${o.reason}`);
      console.log(`  By:     ${o.overriddenBy}`);
      console.log(`  Time:   ${o.timestamp}`);
      console.log('');
    }
    return;
  }

  // Create override
  const gateArg = args.find(a => a.startsWith('--gate='));
  const reasonArg = args.find(a => a.startsWith('--reason='));

  if (!gateArg || !reasonArg) {
    console.error('Usage: right-hooks override --gate=<gate> --reason="<reason>"');
    console.error('');
    console.error('Gates: ci, dod, docConsistency, planningArtifacts, engReview, codeReview, qa, learnings, stopHook');
    process.exit(1);
  }

  const gate = gateArg.split('=')[1];
  const reason = reasonArg.split('=').slice(1).join('=');

  // Get PR number
  let prNum = 'unknown';
  try {
    const branch = execSync('git branch --show-current', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
    prNum = execSync(`gh pr list --head "${branch}" --state open --json number --jq '.[0].number'`, {
      encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'],
    }).trim() || 'unknown';
  } catch {}

  const override = {
    gate,
    pr: prNum === 'unknown' ? prNum : parseInt(prNum),
    reason,
    overriddenBy: 'human',
    timestamp: new Date().toISOString(),
  };

  const filename = `${gate}-PR${prNum}.json`;
  fs.writeFileSync(path.join(overridesDir, filename), JSON.stringify(override, null, 2));
  console.log(`✓ Override created: ${filename}`);
  console.log(`  Gate:   ${gate}`);
  console.log(`  Reason: ${reason}`);
  console.log('\n  This override will be visible in git diff. Commit it with your PR.');
}

module.exports = { run };
