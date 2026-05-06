PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURES_DIR="${PROJECT_ROOT}/tests/fixtures"
MOCKS_DIR="${PROJECT_ROOT}/tests/mocks"

setup_test_env() {
  export PATH="${MOCKS_DIR}:${PATH}"
  export NOTION_TOKEN="test-token-xxx"
  cd "${PROJECT_ROOT}"
}

mock_notion_response() {
  export MOCK_CURL_RESPONSE_FILE="${FIXTURES_DIR}/$1"
}

teardown_test_env() {
  unset MOCK_CURL_RESPONSE_FILE
  unset MOCK_CURL_RESPONSE
  unset MOCK_CURL_EXIT_CODE
}
