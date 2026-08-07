# omarchy-openfortivpn

An [Omarchy](https://github.com/basecamp/omarchy) plugin for [OpenFortiVPN](https://github.com/adrienverge/openfortivpn) — connect to Fortinet VPN gateways directly from your desktop panel, with full SAML/SSO support via [openfortivpn-webview](https://github.com/gm-vm/openfortivpn-webview).

## Features

- 🛡️ **Bar widget** — shows VPN status (connected/disconnected), gateway hostname, and uptime in the Omarchy panel
- 🔐 **SAML/SSO support** — seamless authentication with Azure AD, Okta, and other identity providers via openfortivpn-webview
- 🔑 **Password auth** — standard username/password authentication supported out of the box
- 🔄 **One-click toggle** — left-click the panel widget to connect/disconnect
- 📋 **Context menu** — right-click for config editing, status refresh, and mode info
- 📦 **Clean install/uninstall** — follows Omarchy plugin conventions with `omarchy-install-service` / `omarchy-remove-service`

## Installation

### Prerequisites

- [Omarchy](https://github.com/basecamp/omarchy) installed and running
- `openfortivpn` (installed automatically by the plugin)
- `openfortivpn-webview` (optional, for SAML/SSO — install separately)

### Install the plugin

```bash
# Clone into the Omarchy plugins directory
git clone https://github.com/YOUR_USERNAME/omarchy-openfortivpn \
  ~/.config/omarchy/plugins/omarchy.openfortivpn

# Run the installer
~/.config/omarchy/plugins/omarchy.openfortivpn/bin/omarchy-install-service-openfortivpn
```

### Install SAML/SSO support (optional)

If your VPN gateway uses SAML authentication (Azure AD, Okta, etc.):

```bash
# Arch Linux (AUR)
yay -S openfortivpn-webview-qt

# Or build from source
git clone https://github.com/gm-vm/openfortivpn-webview
cd openfortivpn-webview
# Follow build instructions for your platform
```

## Configuration

Edit `~/.config/openfortivpn/config`:

```ini
# VPN Gateway
host = vpn.example.com
port = 443

# For password auth:
username = your_username
password = your_password

# For SAML/SSO auth (comment out username/password):
# saml = true

# Gateway certificate (get on first connection attempt)
# trusted-cert = <sha256-hash>
```

### Finding your gateway certificate

On first connection, openfortivpn will show the certificate hash:

```bash
sudo openfortivpn vpn.example.com:443 --username=test 2>&1 | grep "Gateway certificate"
```

Copy the hash and add it to your config as `trusted-cert`.

## Usage

### Panel Widget

- **Left-click** — Toggle VPN connection
- **Right-click** — Open context menu (disconnect, edit config, refresh)

### Command Line

```bash
# Connect
omarchy-openfortivpn-up

# Connect with a named config
omarchy-openfortivpn-up mywork

# Disconnect
omarchy-openfortivpn-down

# Check status (JSON output)
omarchy-openfortivpn-status
```

### SAML Workflow

When `saml = true` is set in your config:

1. Click the panel widget (or run `omarchy-openfortivpn-up`)
2. A browser window opens with your identity provider login
3. Complete the MFA/SSO flow
4. The VPN connects automatically after authentication

## Project Structure

```
omarchy-openfortivpn/
├── manifest.json                                    # Omarchy plugin manifest
├── README.md
├── bin/
│   ├── omarchy-install-service-openfortivpn         # Plugin installer
│   ├── omarchy-remove-service-openfortivpn          # Plugin uninstaller
│   ├── omarchy-openfortivpn-up                      # Connect to VPN
│   ├── omarchy-openfortivpn-down                    # Disconnect VPN
│   └── omarchy-openfortivpn-status                  # Check status (JSON)
├── config/
│   └── openfortivpn/
│       └── config.example                           # Example configuration
├── shell/
│   └── plugins/
│       └── panels/
│           └── openfortivpn/
│               └── Panel.qml                        # Bar widget UI
└── systemd/
    └── omarchy-openfortivpn@.service                # Systemd service template
```

## Uninstall

```bash
~/.config/omarchy/plugins/omarchy.openfortivpn/bin/omarchy-remove-service-openfortivpn
rm -rf ~/.config/omarchy/plugins/omarchy.openfortivpn
```

Your VPN config at `~/.config/openfortivpn/` is preserved during uninstall.

## License

MIT
