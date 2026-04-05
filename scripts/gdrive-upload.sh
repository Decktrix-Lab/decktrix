#!/usr/bin/env bash
#
# Upload a file to Google Drive (decktrix folder) and share it.
#
# Usage: ./scripts/gdrive-upload.sh <file>
#
# Credentials stored in: ~/.config/opencode/gdrive-token.json
# If token expires, run: ./scripts/gdrive-auth.sh
#

set -e

TOKEN_FILE="${HOME}/.config/opencode/gdrive-token.json"

if [ -z "$1" ]; then
    echo "Usage: $0 <file>"
    exit 1
fi

FILE="$1"

if [ ! -f "$FILE" ]; then
    echo "Error: File not found: $FILE"
    exit 1
fi

if [ ! -f "$TOKEN_FILE" ]; then
    echo "Error: Token file not found: $TOKEN_FILE"
    echo "Run: ./scripts/gdrive-auth.sh"
    exit 1
fi

CLIENT_ID=$(python3 -c "import json; print(json.load(open('$TOKEN_FILE'))['client_id'])")
CLIENT_SECRET=$(python3 -c "import json; print(json.load(open('$TOKEN_FILE'))['client_secret'])")
REFRESH_TOKEN=$(python3 -c "import json; print(json.load(open('$TOKEN_FILE'))['refresh_token'])")
FOLDER_ID=$(python3 -c "import json; print(json.load(open('$TOKEN_FILE'))['folder_id'])")

# Refresh access token
TOKEN_RESPONSE=$(curl -s -X POST https://oauth2.googleapis.com/token \
    -d "client_id=$CLIENT_ID" \
    -d "client_secret=$CLIENT_SECRET" \
    -d "refresh_token=$REFRESH_TOKEN" \
    -d "grant_type=refresh_token")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)

if [ -z "$ACCESS_TOKEN" ]; then
    echo "Error: Failed to refresh access token. Token may be expired."
    echo "Run: ./scripts/gdrive-auth.sh"
    exit 1
fi

FILENAME=$(basename "$FILE")
MIME_TYPE=$(file -b --mime-type "$FILE")

echo "Uploading $FILENAME ($MIME_TYPE) to Google Drive..."

# Upload file
UPLOAD_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -F "metadata={\"name\": \"$FILENAME\", \"parents\": [\"$FOLDER_ID\"]};type=application/json" \
    -F "file=@$FILE;type=$MIME_TYPE" \
    "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,webViewLink")

FILE_ID=$(echo "$UPLOAD_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
WEB_LINK=$(echo "$UPLOAD_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['webViewLink'])" 2>/dev/null)

if [ -z "$FILE_ID" ]; then
    echo "Error: Upload failed"
    echo "$UPLOAD_RESPONSE"
    exit 1
fi

# Share with anyone who has the link
curl -s -X POST \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"role": "reader", "type": "anyone"}' \
    "https://www.googleapis.com/drive/v3/files/$FILE_ID/permissions" > /dev/null

echo ""
echo "Uploaded: $FILENAME"
echo "Link: $WEB_LINK"
