#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# Quality filter for review/QA comments
# Evaluates comment quality and filters low-value content
# Usage: echo "$COMMENT_BODY" | .right-hooks/hooks/judge.sh
# Exit 0 = post it. Exit 2 = too noisy, re-generate.

RH_HOOK_SELF=$(realpath "$0" 2>/dev/null || echo "$0")

# Minimal preamble — judge doesn't need gh/git
for cmd in jq bc; do
  command -v "$cmd" >/dev/null || { exit 0; }
done

COMMENT=$(cat)
ISSUES=0

# Check: comment is not just praise
PRAISE_LINES=$(echo "$COMMENT" | grep -ciE "looks good|well done|nice work|excellent|great job|well structured|clean code" || true)
TOTAL_LINES=$(echo "$COMMENT" | grep -c . || echo "1")

if [ "$TOTAL_LINES" -gt 0 ]; then
  PRAISE_RATIO=$(echo "scale=2; $PRAISE_LINES / $TOTAL_LINES" | bc 2>/dev/null || true)
  if [ "$(echo "$PRAISE_RATIO > 0.3" | bc -l 2>/dev/null || true)" = "1" ]; then
    ISSUES=$((ISSUES + 1))
    echo "Judge: Too much praise relative to findings ($PRAISE_LINES/$TOTAL_LINES lines)" >&2
  fi
fi

# Check: findings reference specific files/lines
FILE_EXTS=$(cat .right-hooks/active-preset.json 2>/dev/null | jq -r '.orphanDetection.fileExtensions // [".ts",".tsx",".js",".py",".go",".rs"] | map(gsub("\\.";"")) | join("|")' 2>/dev/null || echo "ts|tsx|js|py|go|rs")
HAS_FILE_REFS=$(echo "$COMMENT" | grep -cE "\.(${FILE_EXTS})" || true)
if [ "$HAS_FILE_REFS" -lt 2 ]; then
  ISSUES=$((ISSUES + 1))
  echo "Judge: Findings don't reference specific files (found $HAS_FILE_REFS file references)" >&2
fi

# Check: minimum substance
WORD_COUNT=$(echo "$COMMENT" | wc -w | tr -d ' ')
if [ "$WORD_COUNT" -lt 100 ]; then
  ISSUES=$((ISSUES + 1))
  echo "Judge: Comment too short ($WORD_COUNT words, minimum 100)" >&2
fi

# Check: has severity markers for review comments
HAS_SEVERITY=$(echo "$COMMENT" | grep -ciE "CRITICAL|HIGH|MEDIUM|LOW|INFORMATIONAL" || true)
if [ "$HAS_SEVERITY" -eq 0 ]; then
  ISSUES=$((ISSUES + 1))
  echo "Judge: No severity markers found (use CRITICAL/HIGH/MEDIUM/LOW)" >&2
fi

if [ "$ISSUES" -ge 2 ]; then
  echo "" >&2
  echo "Judge: Comment failed quality check ($ISSUES issues). Re-generate with:" >&2
  echo "  - Specific file references and line numbers" >&2
  echo "  - Severity markers (CRITICAL/HIGH/MEDIUM/LOW)" >&2
  echo "  - Substantive findings (not just praise)" >&2
  echo "  - At least 100 words of analysis" >&2
  exit 2
fi

exit 0
