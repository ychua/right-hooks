#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# Post-edit validation: runs language-specific checks after file edits
# Reads validation config from active-preset.json — never hardcodes tsc/mypy/etc.

RH_HOOK_SELF=$(realpath "$0" 2>/dev/null || echo "$0")
source "$(dirname "$0")/_preamble.sh"

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_result.file_path // .tool_input.file_path // ""' 2>/dev/null)

# No file path — nothing to validate
if [ -z "$FILE" ] || [ "$FILE" = "null" ]; then
  exit 0
fi

# Read active preset
PRESET=$(cat .right-hooks/active-preset.json 2>/dev/null || echo '{}')
FILE_PATTERN=$(echo "$PRESET" | jq -r '.postEditValidation.filePattern // ""' 2>/dev/null)
COMMAND_TPL=$(echo "$PRESET" | jq -r '.postEditValidation.command // ""' 2>/dev/null)

# Skip if no validation configured for this preset
if [ -z "$FILE_PATTERN" ] || [ "$FILE_PATTERN" = "null" ] || [ -z "$COMMAND_TPL" ] || [ "$COMMAND_TPL" = "null" ]; then
  exit 0
fi

# Skip if file doesn't match the preset's pattern
if ! echo "$FILE" | grep -qE "$FILE_PATTERN"; then
  exit 0
fi

# Run validation command (substitute {FILE} placeholder)
COMMAND=$(echo "$COMMAND_TPL" | sed "s|{FILE}|$FILE|g")
ERRORS=$(eval "$COMMAND" 2>&1)
RESULT=$?

if [ $RESULT -ne 0 ] && [ -n "$ERRORS" ]; then
  echo "RIGHT-HOOKS: Validation errors after editing $FILE:" >&2
  echo "$ERRORS" >&2
  exit 2
fi

# Orphan detection for new files
ORPHAN_PATTERN=$(echo "$PRESET" | jq -r '.orphanDetection.importPattern // ""' 2>/dev/null)
if [ -n "$ORPHAN_PATTERN" ] && [ "$ORPHAN_PATTERN" != "null" ]; then
  # Only check if this is a new file (not in git yet)
  if ! git ls-files --error-unmatch "$FILE" >/dev/null 2>&1; then
    BASENAME=$(basename "$FILE" | sed 's/\.[^.]*$//')
    IMPORT_CHECK=$(echo "$ORPHAN_PATTERN" | sed "s|{MODULE}|$BASENAME|g")
    SOURCE_DIRS=$(echo "$PRESET" | jq -r '.postEditValidation.sourceDirs // ["src/"] | join(" ")' 2>/dev/null)
    FILE_EXTS=$(echo "$PRESET" | jq -r '.orphanDetection.fileExtensions // [".ts"] | map("--include=*" + .) | join(" ")' 2>/dev/null)
    
    IMPORTERS=$(eval "grep -rl '$IMPORT_CHECK' $SOURCE_DIRS $FILE_EXTS 2>/dev/null | grep -v '$FILE' | head -1" 2>/dev/null || echo "")
    if [ -z "$IMPORTERS" ]; then
      echo "RIGHT-HOOKS WARNING: New file $FILE has no importers — potential orphan module" >&2
      echo "Make sure something imports this file before merging." >&2
      # Warning only — don't block (exit 0)
    fi
  fi
fi

exit 0
