'use strict';

const fs = require('fs');
const path = require('path');

function run(args) {
  const eventsFile = path.join('.right-hooks', '.stats', 'events.jsonl');

  if (!fs.existsSync(eventsFile)) {
    console.log('No events recorded yet. Events are recorded as hooks run.');
    console.log('Try running some hooks, then check again with: npx right-hooks stats');
    return;
  }

  const raw = fs.readFileSync(eventsFile, 'utf8').trim();
  if (!raw) {
    console.log('No events recorded yet. Events are recorded as hooks run.');
    return;
  }

  const lines = raw.split('\n');
  const events = [];
  let skipped = 0;

  for (const line of lines) {
    try {
      events.push(JSON.parse(line));
    } catch {
      skipped++;
    }
  }

  if (events.length === 0) {
    console.log('No valid events found.');
    if (skipped > 0) console.error(`\u26a0 Skipped ${skipped} malformed line(s)`);
    return;
  }

  if (skipped > 0) {
    console.error(`\u26a0 Skipped ${skipped} malformed line(s)`);
  }

  // Gate table: group by gate, count pass/block (exclude stop events)
  const gateEvents = events.filter(e => e.gate !== 'stop');
  const gates = {};
  for (const e of gateEvents) {
    if (!gates[e.gate]) gates[e.gate] = { pass: 0, block: 0 };
    if (e.result === 'pass') gates[e.gate].pass++;
    else if (e.result === 'block') gates[e.gate].block++;
  }

  // Human involvement: stop pass events grouped by stop_reason
  const stopPassEvents = events.filter(e => e.gate === 'stop' && e.result === 'pass');
  const stopReasons = {};
  for (const e of stopPassEvents) {
    const reason = e.stop_reason || 'unknown';
    stopReasons[reason] = (stopReasons[reason] || 0) + 1;
  }

  // Avg stops per PR (only pass events with a pr number)
  const stopsByPr = {};
  for (const e of stopPassEvents) {
    if (e.pr) {
      stopsByPr[e.pr] = (stopsByPr[e.pr] || 0) + 1;
    }
  }
  const prCount = Object.keys(stopsByPr).length;
  const totalStops = Object.values(stopsByPr).reduce((a, b) => a + b, 0);
  const avgStops = prCount > 0 ? (totalStops / prCount).toFixed(1) : null;

  // Since date
  const timestamps = events.map(e => e.ts).filter(Boolean).sort();
  const since = timestamps.length > 0 ? timestamps[0].split('T')[0] : '\u2014';

  // Print
  console.log('\n\ud83e\udd4a Right Hooks Stats');
  console.log('\u2500'.repeat(47));

  if (Object.keys(gates).length > 0) {
    console.log(
      'Gate'.padEnd(20) +
      'Pass'.padStart(6) +
      'Block'.padStart(7) +
      'Block%'.padStart(8)
    );

    // Sort gates by block% descending
    const sorted = Object.entries(gates).sort((a, b) => {
      const totalA = a[1].pass + a[1].block;
      const totalB = b[1].pass + b[1].block;
      const pctA = totalA > 0 ? a[1].block / totalA : 0;
      const pctB = totalB > 0 ? b[1].block / totalB : 0;
      return pctB - pctA;
    });

    for (const [gate, counts] of sorted) {
      const total = counts.pass + counts.block;
      const pct = total > 0 ? ((counts.block / total) * 100).toFixed(1) : '0.0';
      console.log(
        gate.padEnd(20) +
        String(counts.pass).padStart(6) +
        String(counts.block).padStart(7) +
        `${pct}%`.padStart(8)
      );
    }
  }

  if (Object.keys(stopReasons).length > 0) {
    console.log('');
    console.log('Human Involvement'.padEnd(30) + 'Count'.padStart(6));

    // Sort by count descending
    const sorted = Object.entries(stopReasons).sort((a, b) => b[1] - a[1]);
    for (const [reason, count] of sorted) {
      console.log(reason.padEnd(30) + String(count).padStart(6));
    }
  }

  // Session Failures: group stop_failure events by error type
  const failureEvents = events.filter(e => e.gate === 'stop_failure');
  if (failureEvents.length > 0) {
    const failures = {};
    for (const e of failureEvents) {
      const errorType = e.stop_reason || 'unknown';
      if (!failures[errorType]) {
        failures[errorType] = { count: 0, lastSeen: '' };
      }
      failures[errorType].count++;
      if (e.ts && e.ts > (failures[errorType].lastSeen || '')) {
        failures[errorType].lastSeen = e.ts;
      }
    }

    console.log('');
    console.log(
      'Session Failures'.padEnd(22) +
      'Count'.padStart(6) +
      'Last Seen'.padStart(15)
    );

    const sortedFailures = Object.entries(failures).sort((a, b) => b[1].count - a[1].count);
    for (const [errorType, data] of sortedFailures) {
      const lastDate = data.lastSeen ? data.lastSeen.split('T')[0] : '\u2014';
      console.log(
        errorType.padEnd(22) +
        String(data.count).padStart(6) +
        lastDate.padStart(15)
      );
    }
  }

  console.log('\u2500'.repeat(47));
  console.log(`Total events: ${events.length} | Since: ${since}`);
  if (avgStops !== null) {
    console.log(`Avg stops per PR: ${avgStops} | Ideal (1.0 = fully automated)`);
  }
  console.log('');
}

module.exports = { run };
