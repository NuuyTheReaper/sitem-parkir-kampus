#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 5 ]]; then
  echo "Usage: bash scripts/test_rtdb_service_account.sh path/to/service-account.json database_url [path] [method] [json_payload]" >&2
  echo "Example: bash scripts/test_rtdb_service_account.sh service-account.json https://project-default-rtdb.asia-southeast1.firebasedatabase.app gate_logs GET" >&2
  echo "Query example: bash scripts/test_rtdb_service_account.sh service-account.json https://project-default-rtdb.asia-southeast1.firebasedatabase.app 'users?orderBy=%22%24key%22&limitToFirst=1' GET" >&2
  exit 2
fi

credential_file="$1"
database_url="${2%/}"
path="${3:-}"
method="${4:-GET}"
json_payload="${5:-}"

if [[ ! -f "$credential_file" ]]; then
  echo "Credential file not found: $credential_file" >&2
  exit 2
fi

method="$(printf '%s' "$method" | tr '[:lower:]' '[:upper:]')"
case "$method" in
  GET|POST|PUT|PATCH|DELETE) ;;
  *)
    echo "Unsupported method: $method" >&2
    exit 2
    ;;
esac

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

key_file="$tmp_dir/private_key.pem"
payload_file="$tmp_dir/rtdb_payload.json"

client_email="$(
  python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["client_email"])' "$credential_file"
)"
project_id="$(
  python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("project_id", ""))' "$credential_file"
)"
python3 -c 'import json, sys; open(sys.argv[2], "w").write(json.load(open(sys.argv[1]))["private_key"])' "$credential_file" "$key_file"
chmod 600 "$key_file"

base64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

now="$(date +%s)"
exp="$((now + 3600))"
scope="https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/firebase.database"
audience="https://oauth2.googleapis.com/token"

header='{"alg":"RS256","typ":"JWT"}'
payload="$(
  python3 -c 'import json, sys; print(json.dumps({
    "iss": sys.argv[1],
    "scope": sys.argv[2],
    "aud": sys.argv[3],
    "iat": int(sys.argv[4]),
    "exp": int(sys.argv[5]),
  }, separators=(",", ":")))' "$client_email" "$scope" "$audience" "$now" "$exp"
)"

encoded_header="$(printf '%s' "$header" | base64url)"
encoded_payload="$(printf '%s' "$payload" | base64url)"
signing_input="${encoded_header}.${encoded_payload}"
signature="$(printf '%s' "$signing_input" | openssl dgst -sha256 -sign "$key_file" | base64url)"
jwt="${signing_input}.${signature}"

token_response="$(
  curl -sS \
    -w '\n%{http_code}' \
    -X POST "$audience" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer' \
    --data-urlencode "assertion=$jwt"
)"

token_http_code="${token_response##*$'\n'}"
token_body="${token_response%$'\n'*}"
access_token="$(
  printf '%s' "$token_body" | python3 -c 'import json, sys
data = json.loads(sys.stdin.read())
if "access_token" not in data:
    print("OAuth failed with HTTP " + sys.argv[1], file=sys.stderr)
    print("Reason: " + str(data.get("error", "-")), file=sys.stderr)
    print("Description: " + str(data.get("error_description", data.get("detail", "-"))), file=sys.stderr)
    sys.exit(1)
print(data["access_token"])' "$token_http_code"
)"

path="${path#/}"
query_string=""
if [[ "$path" == *"?"* ]]; then
  query_string="${path#*\?}"
  path="${path%%\?*}"
fi
path="${path%.json}"
if [[ -n "$path" ]]; then
  request_url="${database_url}/${path}.json"
else
  request_url="${database_url}/.json"
fi
if [[ -n "$query_string" ]]; then
  request_url="${request_url}?${query_string}"
fi

if [[ "$method" == "GET" ]]; then
  if [[ "$request_url" == *"?"* ]]; then
    if [[ "$request_url" != *"print="* ]]; then
      request_url="${request_url}&print=pretty"
    fi
  else
    request_url="${request_url}?shallow=true&print=pretty"
  fi
fi

curl_args=(
  -sS
  -w '\nHTTP_STATUS=%{http_code}\n'
  -X "$method"
  "$request_url"
  -H "Authorization: Bearer ${access_token}"
)

if [[ "$method" != "GET" && "$method" != "DELETE" ]]; then
  if [[ -z "$json_payload" ]]; then
    echo "Method $method needs json_payload argument." >&2
    exit 2
  fi
  printf '%s' "$json_payload" > "$payload_file"
  curl_args+=(
    -H 'Content-Type: application/json'
    --data-binary "@${payload_file}"
  )
fi

echo "Project: ${project_id:-"-"}"
echo "Database: $database_url"
echo "Path: /${path:-""}"
echo "Method: $method"
curl "${curl_args[@]}"
