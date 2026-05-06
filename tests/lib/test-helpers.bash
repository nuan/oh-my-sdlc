PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURES_DIR="${PROJECT_ROOT}/tests/fixtures"
MOCKS_DIR="${PROJECT_ROOT}/tests/mocks"

setup_test_env() {
  [ -d "$MOCKS_DIR" ] || { echo "ERROR: MOCKS_DIR not found: $MOCKS_DIR" >&2; return 1; }
  export PATH="${MOCKS_DIR}:${PATH}"
  export NOTION_TOKEN="test-token-xxx"
  cd "${PROJECT_ROOT}"
}

mock_notion_response() {
  local fixture_file="${FIXTURES_DIR}/$1"
  [ -f "$fixture_file" ] || { echo "ERROR: Fixture not found: $fixture_file" >&2; return 1; }
  export MOCK_CURL_RESPONSE_FILE="$fixture_file"
}

teardown_test_env() {
  unset MOCK_CURL_RESPONSE_FILE
  unset MOCK_CURL_RESPONSE
  unset MOCK_CURL_EXIT_CODE
}
