'use strict';

const fs = require('fs');
const path = require('path');

const DETECTORS = [
  {
    name: 'typescript',
    files: ['tsconfig.json'],
    label: 'TypeScript',
    extras: [],
  },
  {
    name: 'python',
    files: ['pyproject.toml', 'setup.py', 'requirements.txt'],
    label: 'Python',
    extras: [
    ],
  },
  {
    name: 'go',
    files: ['go.mod'],
    label: 'Go',
    extras: [],
  },
  {
    name: 'rust',
    files: ['Cargo.toml'],
    label: 'Rust',
    extras: [],
  },
];

function detect(projectDir) {
  projectDir = projectDir || process.cwd();
  const results = { preset: 'generic', detected: [] };

  for (const detector of DETECTORS) {
    for (const file of detector.files) {
      if (fs.existsSync(path.join(projectDir, file))) {
        results.preset = detector.name;
        results.detected.push({ type: detector.label, file });

        // Check extras
        if (detector.extras) {
          for (const extra of detector.extras) {
            for (const ef of extra.files) {
              if (fs.existsSync(path.join(projectDir, ef))) {
                results.detected.push({ type: extra.label, file: ef });
              }
            }
          }
        }
        break;
      }
    }
    if (results.preset !== 'generic') break;
  }

  // Check GitHub
  try {
    const { execSync } = require('child_process');
    execSync('gh auth status', { stdio: 'pipe' });
    results.detected.push({ type: 'GitHub repo', file: 'gh auth status ok' });
  } catch {
    // gh not available or not authenticated
  }

  return results;
}

module.exports = { detect, DETECTORS };
