'use strict';

/**
 * Additive merge of shipped settings.json hooks into an existing settings.json.
 *
 * For each hook event in the shipped config, checks for duplicate commands
 * using a Set and appends only new hooks that don't already exist.
 *
 * Does NOT mutate input objects — returns a new merged object.
 *
 * @param {Object} existing - The user's current settings.json content
 * @param {Object} shipped  - The package's shipped settings.json content
 * @returns {Object} A new settings object with merged hooks
 */
function mergeSettings(existing, shipped) {
  const result = { ...existing };
  const existingHooks = existing.hooks || {};
  const shippedHooks = (shipped && shipped.hooks) || {};

  const mergedHooks = { ...existingHooks };

  for (const [event, entries] of Object.entries(shippedHooks)) {
    if (!mergedHooks[event]) {
      // New event — copy it wholesale
      mergedHooks[event] = entries.map(entry => ({ ...entry, hooks: [...(entry.hooks || [])] }));
    } else {
      // Existing event — append only commands that don't already exist
      const existingCmds = new Set(
        mergedHooks[event].flatMap(e => (e.hooks || []).map(h => h.command))
      );
      for (const entry of entries) {
        const newHooks = (entry.hooks || []).filter(h => !existingCmds.has(h.command));
        if (newHooks.length > 0) {
          mergedHooks[event] = [
            ...mergedHooks[event],
            { ...entry, hooks: newHooks },
          ];
        }
      }
    }
  }

  return { ...result, hooks: mergedHooks };
}

module.exports = { mergeSettings };
