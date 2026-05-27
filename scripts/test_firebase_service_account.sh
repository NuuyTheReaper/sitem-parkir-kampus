#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: bash scripts/test_firebase_service_account.sh path/to/service-account.json" >&2
  exit 2
fi

credential_file="$1"

if [[ ! -f "$credential_file" ]]; then
  echo "Credential file not found: $credential_file" >&2
  exit 2
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

key_file="$tmp_dir/private_key.pem"

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
scope="${TOKEN_SCOPES:-https://www.googleapis.com/auth/firebase.messaging https://www.googleapis.com/auth/cloud-platform}"
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

response="$(
  curl -sS \
    -w '\n%{http_code}' \
    -X POST "$audience" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer' \
    --data-urlencode "assertion=$jwt"
)"

http_code="${response##*$'\n'}"
body="${response%$'\n'*}"

printf '%s' "$body" | python3 -c 'import json, os, sys
project_id = sys.argv[1]
http_code = sys.argv[2]
body = sys.stdin.read()
try:
    data = json.loads(body)
except json.JSONDecodeError:
    print(f"ERROR: OAuth returned HTTP {http_code}, but the body was not JSON.")
    sys.exit(1)

if "access_token" in data:
    print("SUCCESS: service account JSON is valid and OAuth token exchange worked.")
    print("Project: " + (project_id or "-"))
    print("Token type: " + str(data.get("token_type", "-")))
    print("Expires in: " + str(data.get("expires_in", "-")) + " seconds")
    if os.environ.get("PRINT_TOKEN", "").lower() in ("1", "true", "yes", "y"):
        print("Access token: " + data["access_token"])
    sys.exit(0)

print(f"ERROR: OAuth token exchange failed with HTTP {http_code}.")
print("Reason: " + str(data.get("error", "-")))
print("Description: " + str(data.get("error_description", data.get("detail", "-"))))
sys.exit(1)' "$project_id" "$http_code"
