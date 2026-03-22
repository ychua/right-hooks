#!/usr/bin/env bash
# Mock gh CLI for bashunit integration tests
# Responds based on MOCK_* environment variables

case "$1" in
  auth)
    echo "✓ Logged in to github.com account testuser"
    exit 0
    ;;
  repo)
    if echo "$*" | grep -q "\-\-jq"; then
      echo "testuser/testrepo"
    else
      echo '{"nameWithOwner":"testuser/testrepo"}'
    fi
    exit 0
    ;;
  pr)
    case "$2" in
      list)
        if [ "${MOCK_PR_EXISTS:-}" = "1" ]; then
          if echo "$*" | grep -q "\-\-jq"; then
            echo "${MOCK_PR_NUMBER:-1}"
          else
            echo "[{\"number\":${MOCK_PR_NUMBER:-1},\"title\":\"Test PR\"}]"
          fi
        else
          echo ""
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
        [ "${MOCK_HAS_LEARNINGS:-}" = "1" ] && echo "docs/retros/test-feature-learnings.md"
        [ "${MOCK_HAS_DESIGN_DOC:-}" = "1" ] && echo "docs/designs/test-feature.md"
        [ "${MOCK_HAS_EXEC_PLAN:-}" = "1" ] && echo "docs/exec-plans/test-feature.md"
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
    # Individual comment lookup (sentinel verification): /issues/comments/{id}
    if echo "$*" | grep -qE 'comments/[0-9]+'; then
      COMMENT_ID=$(echo "$*" | grep -oE 'comments/[0-9]+' | grep -oE '[0-9]+')
      printf '{"id":%s}' "$COMMENT_ID"
      exit 0
    fi
    # List all comments on a PR
    if echo "$*" | grep -q "comments"; then
      COMMENTS="[]"
      # Build comment array as valid JSON — use printf to avoid \n issues
      ITEMS=""
      if [ "${MOCK_HAS_REVIEW:-}" = "1" ]; then
        ITEMS='{"body":"## Review Agent\\n**Severity:** MEDIUM\\nFindings in src/index.ts"}'
      fi
      if [ "${MOCK_HAS_QA:-}" = "1" ]; then
        [ -n "$ITEMS" ] && ITEMS="$ITEMS,"
        ITEMS="${ITEMS}"'{"body":"## QA Agent\\nAll tests passing, coverage 95%"}'
      fi
      if [ "${MOCK_HAS_DOC:-}" = "1" ]; then
        [ -n "$ITEMS" ] && ITEMS="$ITEMS,"
        ITEMS="${ITEMS}"'{"body":"Documentation health: all docs consistent with code changes"}'
      fi
      printf '[%s]' "$ITEMS"
    fi
    ;;
  *)
    echo "mock-gh: unhandled command: $*" >&2
    exit 1
    ;;
esac
