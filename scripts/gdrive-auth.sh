#!/usr/bin/env bash
#
# Re-authenticate with Google Drive when the refresh token expires.
# The refresh token lasts 7 days. When it expires, run this script.
#
# Usage: ./scripts/gdrive-auth.sh
#
# Steps:
# 1. Opens the OAuth URL in your browser
# 2. You approve access
# 3. Browser redirects to http://localhost/?code=...
# 4. Copy the code from the URL and paste it here
# 5. Token file is updated automatically
#

set -e

TOKEN_FILE="${HOME}/.config/opencode/gdrive-token.json"

if [ ! -f "$TOKEN_FILE" ]; then
    echo "Error: Token file not found: $TOKEN_FILE"
    exit 1
fi

CLIENT_ID=$(python3 -c "import json; print(json.load(open('$TOKEN_FILE'))['client_id'])")
CLIENT_SECRET=$(python3 -c "import json; print(json.load(open('$TOKEN_FILE'))['client_secret'])")
REDIRECT_URI="http://localhost"

AUTH_URL="https://accounts.google.com/o/oauth2/auth?client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&response_type=code&scope=https://www.googleapis.com/auth/drive.file&access_type=offline&prompt=consent"

echo ""
echo "Open this URL in your browser to authorize:"
echo ""
echo "$AUTH_URL"
echo ""
echo "After approving, you will be redirected to:"
echo "  http://localhost/?code=XXXXX&scope=..."
echo ""
read -p "Paste the code from the URL: " AUTH_CODE

if [ -z "$AUTH_CODE" ]; then
    echo "Error: No code provided"
    exit 1
fi

# Exchange code for tokens
TOKEN_RESPONSE=$(curl -s -X POST https://oauth2.googleapis.com/token \
    -d "code=$AUTH_CODE" \
    -d "client_id=$CLIENT_ID" \
    -d "client_secret=$CLIENT_SECRET" \
    -d "redirect_uri=$REDIRECT_URI" \
    -d "grant_type=authorization_code")

NEW_ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)
NEW_REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['refresh_token'])" 2>/dev/null)

if [ -z "$NEW_REFRESH_TOKEN" ]; then
    echo "Error: Failed to get new tokens"
    echo "$TOKEN_RESPONSE"
    exit 1
fi

# Update token file with new refresh token
python3 -c "
import json
with open('$TOKEN_FILE', 'r') as f:
    data = json.load(f)
data['refresh_token'] = '$NEW_REFRESH_TOKEN'
with open('$TOKEN_FILE', 'w') as f:
    json.dump(data, f, indent=2)
"

echo ""
echo "Token updated successfully!"
echo "You can now use: ./scripts/gdrive-upload.sh <file>"
