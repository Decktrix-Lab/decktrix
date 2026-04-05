# AGENTS.md

## Google Drive Upload

To upload a file to the shared Google Drive folder:

```bash
./scripts/gdrive-upload.sh <path-to-file>
```

This will:
1. Refresh the access token using the stored refresh token
2. Upload the file to the decktrix folder on Google Drive
3. Share it with "anyone with link"
4. Print the shareable URL

Credentials are stored in `~/.config/opencode/gdrive-token.json`.

### When the token expires (after 7 days)

The refresh token expires after 7 days. When this happens:
1. `gdrive-upload.sh` will fail with "Failed to refresh access token"
2. Run `./scripts/gdrive-auth.sh`
3. It prints an OAuth URL - open it in a browser
4. Approve access in Google
5. Browser redirects to `http://localhost/?code=XXXXX...`
6. Copy the `code` value from the URL and paste it into the terminal
7. The script updates the token file automatically
8. Run `gdrive-upload.sh` again

### Google Cloud project

- Project: decktrix
- OAuth Client ID: `236838812265-94votd2clqtuoc10ang7lidqegrqlbdh.apps.googleusercontent.com`
- Folder: `1GEBlgEZuuIjffJXl2PR23m1ojAJ_IQYR`
- OAuth credentials stored in: `~/.config/opencode/gcp-oauth.json`
