#!/bin/sh

# Check for jq
if ! command -v jq &> /dev/null
then
    echo "❌ 'jq' is not installed. Please install it to run this script."
    echo "   On Debian/Ubuntu: sudo apt-get install jq"
    echo "   On macOS: brew install jq"
    exit 1
fi

read -p "Enter client id: " CLIENT_ID
read -sp "Enter client secret: " CLIENT_SECRET
echo "" # Add a newline after the silent prompt

SCOPE="https://www.googleapis.com/auth/drive.file"
REDIRECT_URI="http://localhost"

AUTH_URL="https://accounts.google.com/o/oauth2/v2/auth?scope=${SCOPE}&access_type=offline&include_granted_scopes=true&response_type=code&redirect_uri=${REDIRECT_URI}&client_id=${CLIENT_ID}&prompt=consent"

echo "Open this URL in your browser:"
echo $AUTH_URL

read -p "Paste the full redirect URL from your browser here: " REDIRECT_URL
RAW_AUTH_CODE=$(echo "$REDIRECT_URL" | grep -o 'code=[^&]*' | cut -d'=' -f2)

# URL-decode the authorization code
AUTH_CODE=$(printf '%b' "$(echo "$RAW_AUTH_CODE" | sed 's/+/ /g;s/%\(..\)/\\x\1/g')")

echo "" # Add a newline for better formatting

if [ -z "$AUTH_CODE" ]; then
  echo "❌ Could not extract authorization code from the URL."
  exit 1
fi

echo "✅ Authorization code extracted. Exchanging for refresh token..."

TOKEN_RESPONSE=$(curl -s --request POST \
  --url https://oauth2.googleapis.com/token \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "code=${AUTH_CODE}" \
  --data-urlencode "client_id=${CLIENT_ID}" \
  --data-urlencode "client_secret=${CLIENT_SECRET}" \
  --data-urlencode "redirect_uri=${REDIRECT_URI}" \
  --data-urlencode "grant_type=authorization_code")

REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r .refresh_token)

if [ -z "$REFRESH_TOKEN" ] || [ "$REFRESH_TOKEN" = "null" ]; then
  echo "❌ Failed to get refresh token from Google."
  echo "   Error response:"
  echo "$TOKEN_RESPONSE"
  exit 1
fi

echo "✅ Successfully obtained refresh token."

COMBINED_SECRET="${CLIENT_ID}|${REFRESH_TOKEN}|${CLIENT_SECRET}"
ENCODED_SECRET=$(echo -n "$COMBINED_SECRET" | base64 -w 0)

echo ""
echo "========================================================================"
echo "🎉 Success! Here is your Base64 encoded secret for GitHub:"
echo "========================================================================"
echo ""
echo "$ENCODED_SECRET"
echo ""
echo "➡️  Copy the value above and save it as the 'GDRIVE_OAUTH2' secret in your GitHub repository settings."
echo "========================================================================"
echo "⚠️  Keep this value safe and do not share it with anyone! ⚠️"
echo "========================================================================"
