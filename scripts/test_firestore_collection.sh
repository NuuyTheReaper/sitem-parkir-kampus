#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
  echo "Usage: bash scripts/test_firestore_collection.sh path/to/service-account.json [collection_name] [document_id]" >&2
  exit 2
fi

credential_file="$1"
collection_name="${2:-codex_test_collection}"
document_id="${3:-}"

if [[ ! -f "$credential_file" ]]; then
  echo "Credential file not found: $credential_file" >&2
  exit 2
fi

if [[ "$collection_name" == *"/"* || -z "$collection_name" ]]; then
  echo "Use a single Firestore collection name without slashes." >&2
  exit 2
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

key_file="$tmp_dir/private_key.pem"
payload_file="$tmp_dir/firestore_payload.json"

client_email="$(
  python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["client_email"])' "$credential_file"
)"
project_id="$(
  python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["project_id"])' "$credential_file"
)"
python3 -c 'import json, sys; open(sys.argv[2], "w").write(json.load(open(sys.argv[1]))["private_key"])' "$credential_file" "$key_file"
chmod 600 "$key_file"

base64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

now="$(date +%s)"
exp="$((now + 3600))"
scope="https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/cloud-platform"
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

created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
python3 -c 'import json, sys
payload = {
    "fields": {
        "source": {"stringValue": "codex-firestore-test"},
        "message": {"stringValue": "Test write from service account"},
        "project_id": {"stringValue": sys.argv[1]},
        "created_at": {"timestampValue": sys.argv[2]},
        "verified": {"booleanValue": True},
    }
}
open(sys.argv[3], "w").write(json.dumps(payload, separators=(",", ":")))' "$project_id" "$created_at" "$payload_file"

url="https://firestore.googleapis.com/v1/projects/${project_id}/databases/(default)/documents/${collection_name}"
if [[ -n "$document_id" ]]; then
  url="${url}?documentId=${document_id}"
fi

firestore_response="$(
  curl -sS \
    -w '\n%{http_code}' \
    -X POST "$url" \
    -H "Authorization: Bearer ${access_token}" \
    -H 'Content-Type: application/json' \
    --data-binary "@${payload_file}"
)"

firestore_http_code="${firestore_response##*$'\n'}"
firestore_body="${firestore_response%$'\n'*}"

printf '%s' "$firestore_body" | python3 -c 'import json, sys
http_code = sys.argv[1]
project_id = sys.argv[2]
collection_name = sys.argv[3]
body = sys.stdin.read()
try:
    data = json.loads(body)
except json.JSONDecodeError:
    print("ERROR: Firestore returned HTTP " + http_code + ", but the body was not JSON.")
    sys.exit(1)

if http_code.startswith("2") and "name" in data:
    print("SUCCESS: Firestore document created.")
    print("Project: " + project_id)
    print("Collection: " + collection_name)
    print("Document path: " + data["name"])
    print("Created at: " + str(data.get("createTime", "-")))
    sys.exit(0)

print("ERROR: Firestore write failed with HTTP " + http_code + ".")
error = data.get("error", data)
print("Status: " + str(error.get("status", "-") if isinstance(error, dict) else "-"))
print("Message: " + str(error.get("message", error) if isinstance(error, dict) else error))
sys.exit(1)' "$firestore_http_code" "$project_id" "$collection_name"
