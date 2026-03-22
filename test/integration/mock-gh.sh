#!/usr/bin/env bash
# Mock gh CLI for integration tests
# Responds based on MOCK_* environment variables

case "$1" in
  auth)
    echo "✓ Logged in to github.com account testuser"
    exit 0
    ;;
  repo)
    echo '{"nameWithOwner":"testuser/testrepo"}'
    exit 0
    ;;
  pr)
    case "$2" in
      list)
        if [ "${MOCK_PR_EXISTS:-}" = "1" ]; then
          echo "[{\"number\":${MOCK_PR_NUMBER:-1},\"title\":\"Test PR\"}]"
        else
          echo "[]"
        fi
        ;;
      checks)
        if [ "${MOCK_CI_FAILING:-}" = "1" ]; then
          echo "fail	build	1m	https://ci/1"
        else
          echo "pass	build	1m	https://ci/1"
          echo "pass	lint	30s	https://ci/2"
        fi
        ;;
      view)
        if echo "$*" | grep -q "body"; then
          if [ "${MOCK_DOD_INCOMPLETE:-}" = "1" ]; then
            echo "- [ ] Unchecked item"
            echo "- [x] Done item"
          else
            echo "- [x] All done"
            echo "- [x] Tests pass"
          fi
        else
          echo '{"number":'${MOCK_PR_NUMBER:-1}',"title":"Test PR"}'
        fi
        ;;
      diff)
        if [ "${MOCK_HAS_LEARNINGS:-}" = "1" ]; then
          echo "docs/retros/test-feature-learnings.md"
        fi
        if [ "${MOCK_HAS_DESIGN_DOC:-}" = "1" ]; then
          echo "docs/designs/test-feature.md"
        fi
        if [ "${MOCK_HAS_EXEC_PLAN:-}" = "1" ]; then
          echo "docs/exec-plans/test-feature.md"
        fi
        ;;
      create)
        echo "https://github.com/testuser/testrepo/pull/${MOCK_PR_NUMBER:-1}"
        ;;
      merge)
        echo "✓ Merged"
        ;;
    esac
    ;;
  api)
    # PR comments endpoint
    if echo "$*" | grep -q "comments"; then
      COMMENTS="[]"
      if [ "${MOCK_HAS_REVIEW:-}" = "1" ]; then
        COMMENTS='[{"body":"## Code Review\n**Severity:** MEDIUM\nFindings in src/index.ts"}]'
      fi
      if [ "${MOCK_HAS_QA:-}" = "1" ]; then
        if [ "$COMMENTS" = "[]" ]; then
          COMMENTS='[{"body":"## QA Review\nAll tests passing, coverage 95%"}]'
        else
          COMMENTS=$(echo "$COMMENTS" | sed 's/\]$/,{"body":"## QA Review\\nAll tests passing, coverage 95%"}]/')
        fi
      fi
      echo "$COMMENTS"
    fi
    ;;
  *)
    echo "mock-gh: unhandled command: $*" >&2
    exit 1
    ;;
esac
