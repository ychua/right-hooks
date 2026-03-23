'use strict';

/**
 * Field-level merge of shipped skills.json into an existing skills.json.
 *
 * For each gate (codeReview, qa, docConsistency):
 * - Preserves the user's existing fields (skill, provider, fallback, etc.)
 * - Adds any NEW fields from shipped config that don't exist in the user's file
 * - Never overwrites fields the user already has
 * - Adds entirely new gates from shipped config
 *
 * Does NOT mutate input objects — returns a new merged object.
 *
 * @param {Object} existing - The user's current skills.json content
 * @param {Object} shipped  - The package's shipped skills.json content
 * @returns {Object} A new skills object with merged fields
 */
function mergeSkills(existing, shipped) {
  const result = {};

  // Start with all existing gates (preserves user data)
  for (const [gate, fields] of Object.entries(existing)) {
    result[gate] = { ...fields };
  }

  // Add new fields and new gates from shipped config
  for (const [gate, shippedFields] of Object.entries(shipped)) {
    if (!result[gate]) {
      // Entirely new gate — add it wholesale
      result[gate] = { ...shippedFields };
    } else {
      // Existing gate — add only fields that don't exist yet
      for (const [field, value] of Object.entries(shippedFields)) {
        if (!(field in result[gate])) {
          result[gate] = { ...result[gate], [field]: value };
        }
      }
    }
  }

  return result;
}

module.exports = { mergeSkills };
