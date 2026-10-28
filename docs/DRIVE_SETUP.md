# Google Drive backup: setup

The Drive backup is real: it signs in to your Google account and keeps ONE file,
`qrm-backup.json`, in the app's own hidden Drive folder. Nothing in the source
can do the one step that belongs to you: **Google must be told that this app
exists**. That is a one-time job in the Google Cloud Console, about ten minutes.
Until it is done, the Drive dialog says "Google Drive is not set up in this
build" and the backup file (save to a place you choose, import from storage) and
the copy-and-paste export/import still work.

## 1. Create the OAuth client (once)

1. Open <https://console.cloud.google.com/> and create a project (or pick one).
2. **APIs & Services > Library**: search "Google Drive API" and **Enable** it.
3. **OAuth consent screen** (called "Google Auth Platform" in newer consoles):
   - User type **External**; app name (anything), your e-mail as support and
     developer contact.
   - **Scopes**: add `.../auth/drive.file` ("See, edit, create, and delete only the specific Google Drive files you use with this app") and `.../auth/userinfo.email`
     (and `openid`). These are the only two the app asks for. It cannot see
     your other Drive files.
   - **Audience / test users**: while the app is in *Testing*, add your own
     Google account as a test user, or Google refuses the sign-in.
4. **Credentials > Create credentials > OAuth client ID**:
   - Application type: **TVs and Limited Input devices**. This is the type that
     allows the code flow the app uses; a "Web", "Android" or "iOS" client does
     not work with it.
   - Create it, then copy the **Client ID** and the **Client secret**. (Google
     does not treat the secret of this kind of installed app as confidential,
     but it still does not belong in git.)

## 2. Give the app the client at build time

The two values are not in the source. Pass them with `--dart-define`:

    flutter run \
      --dart-define=GOOGLE_DRIVE_CLIENT_ID=1234-abcd.apps.googleusercontent.com \
      --dart-define=GOOGLE_DRIVE_CLIENT_SECRET=GOCSPX-...

or keep them in a file that git ignores (`/drive.json` is in `.gitignore`):

    { "GOOGLE_DRIVE_CLIENT_ID": "...", "GOOGLE_DRIVE_CLIENT_SECRET": "..." }

    flutter run --dart-define-from-file=drive.json
    flutter build apk --dart-define-from-file=drive.json

Use the same flags for every build you install (`flutter build ...`): a build
made without them has no Drive.

## 3. Connect

Settings > Cloud Backup & Device Sync > **Connect**. The app shows a short code
(like `ABCD-EFGH`) and a link (google.com/device). Open the link on any device,
enter the code, choose your account, allow. The app notices by itself and shows
"Google Drive Connected (your address)". There is no browser inside the app and
no redirect, so it works the same on Android, iOS, Windows and macOS.

Then:

- **Backup Now** writes the backup (progress, settings, study history and notes)
  to Drive, replacing the previous one.
- **Restore** reads it back after a confirmation; it replaces the progress,
  settings, history and notes on this device. This device's own Drive connection
  is kept.
- **Auto-backup** (manual / daily / weekly) runs when the app starts and when it
  comes back to the front, only if the last backup is older than the frequency.
  It is silent; a failure just tries again the next time.
- **Disconnect** signs out here and revokes the sign-in at Google. The backup
  stays on Drive.

A backup is refused while the first-run setup is not done, so a new install can
never replace a good backup on Drive with an empty state.

## Restoring on a new install

The first-run screen ("Set up your Q", step 1) has an **Already have data?**
card with three ways to restore instead of setting up from scratch:

- **Restore from Google Drive**: connect the account (the same code flow as
  above), the app looks for `qrm-backup.json` and shows when it was saved, then
  **Restore this backup**. No backup on the account? It says so, and "Use another
  account" signs out so you can connect the right one. This dialog has no Backup
  Now and no auto-backup setting: there is nothing to back up yet.
- **Import from file**: opens the file chooser at once; pick a backup file from
  storage and restore it.
- **Paste backup text**: the same import dialog, on its paste field.

## Backup as a file

Settings > Cloud Backup & Device Sync:

- **Export Backup (JSON)** > **Save to file...** opens the system "save as"
  dialog (Windows, Android) so you choose the folder and the name; the suggested
  name is `qrm-backup-YYYY-MM-DD.json`. In a browser it is a normal download
  (the browser decides the folder, or asks, by its own setting). **Copy to
  Clipboard** is still there.
- **Import Backup (file or text)** > **Choose backup file...** picks a `.json`
  (or `.txt`) file from storage and shows what it holds (pages, days, notes, when
  it was exported) before anything is replaced; pasting the text works as before.
  When this device already has data, a restore asks first.

The dialogs are `package:file_picker` (kept on 11.x because 12 and later need
win32 6, which `flutter_secure_storage` 9.x cannot have), behind the small
`BackupFiles` interface (`features/backup/services/backup_files.dart`), so tests
use a fake.

## Where things are kept

- The backup: `qrm-backup.json` in Google Drive (the app can only access files it created itself). To remove it: delete the file from Drive, or revoke access in your Google Account.
- The sign-in (a refresh token) and the e-mail: the device's secure storage
  (`flutter_secure_storage`), never `shared_preferences`, never the backup.

## Troubleshooting

| What you see | Why |
| --- | --- |
| "not set up in this build" | built without the two `--dart-define` values |
| `invalid_client` | wrong Client ID/secret, or the client type is not "TVs and Limited Input devices" |
| "Access to Google Drive was refused" / `access_denied` | your account is not a test user (app in *Testing*), or you pressed Cancel at Google |
| "Google Drive API has not been used in project..." | step 1.2: enable the Drive API in the same project |
| "The Google sign-in has ended. Disconnect and connect again." | the refresh token was revoked, or expired: a project left in *Testing* ends sign-ins after **7 days**. Publish the consent screen ("In production") for lasting sign-ins; the scopes used are not sensitive ones, so a personal app is not supposed to need Google's review, but check what the console says for your project |
| "There is nothing to back up yet" | finish the first-run setup first |

## Known limits

- **Not tested against Google.** The tests use a fake Drive and a fake token
  endpoint; nobody has yet run the sign-in against the real servers. The first
  real try is the real test.
- **Flutter web is probably not usable** for Drive: a browser is likely to block
  the calls to Google's device-code endpoint (CORS). The web build was not
  tried. Export/Import (copy and paste) works everywhere.
- One backup, one file: there is no history of older backups on Drive.
