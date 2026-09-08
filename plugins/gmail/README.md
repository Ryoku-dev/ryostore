# Gmail Plugin for Ryoku

Native industrial noir Gmail client and notification reader plugin for the [Ryoku](https://github.com/neur0map/ryoku) desktop shell.

## Features

- **Ryoku Industrial Design:** Styled to match the Ryoku design language with hairline borders, Japanese typography markers, and live Matugen color scheme integration.
- **OAuth 2.0 PKCE:** Direct loopback authorization on `http://localhost:42069/callback`. Tokens are stored strictly locally in `~/.config/ryoku/` with zero telemetry or cloud relays.
- **Custom Geometry:** Configurable popup width (480px–960px) and height (440px–720px) directly from Ryoku Settings.
- **Full Mailbox Management:** Browse Inbox, Sent, Spam, and Trash with real-time search, read threads, view HTML/plain text, and compose/send emails.

---

## Google Cloud OAuth Setup Guide

To connect your Gmail account, you will need a free Google Cloud OAuth Client ID and Client Secret:

### 1. Create a Google Cloud Project
1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Click the **Select a project** dropdown at the top of the page.
3. Click **New Project**, give it a name (e.g. `Ryoku Mail`), and click **Create**.

### 2. Enable the Gmail API
1. In the left panel, select **APIs & Services** → **Library**.
2. Search for **Gmail API** and click **Enable**.

### 3. Start OAuth Consent Screen Setup
1. On the same Gmail API screen, click **Credentials** (in the center of the page, not the left panel).
2. Click **Create Credentials** → **OAuth client ID**.
3. Click **Configure consent screen** > **Get started**.

### 4. Fill App Information & Create
1. Fill in the required fields: **App name** (e.g. `Ryoku Mail`), **User support email**, and **Developer contact information**.
2. Click **Save and Continue**, agree to the policy, and click **Create**.

### 5. Create Desktop App Credentials
1. Return to the main dashboard and select **Gmail API** > **Manage** > **Credentials** (center page, not left panel).
2. Click **Create Credentials** > **OAuth client ID**.
3. Choose **Desktop App** type from the dropdown, enter a name for your client, and click **Create**.

### 6. Save Your Keys Below
1. A popup will appear displaying your **Client ID** and **Client Secret**.
2. Copy and paste them into the input fields in the Ryoku Gmail plugin, then click **Save Credentials & Continue**.

### 7. Authorize & Grant Permissions in Browser
1. Click **Connect with Google**.
2. The setup screen will open in your default browser. Select your Gmail account.
3. When Google displays a warning (**"Google hasn't verified this app"**):
   - Click **Show advanced**
   - Click **Go to [Your Project Name] (unsafe)**
   - Check all requested Gmail permissions and click **Continue** to complete setup!

---

## License

MIT
