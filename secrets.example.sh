#!/bin/sh
# Copy to secrets.sh and fill in your own values:
#   cp secrets.example.sh secrets.sh
#   chmod 600 secrets.sh
#   . ./secrets.sh
# secrets.sh is excluded by .gitignore (never commit it).

# Login password of the 'marble' user on the phone
MARBLE_PASSWORD='your-login-password'

# LAN address of the phone
PHONE_IP='192.168.1.xxx'

# Wi-Fi credentials (used only when baking the image)
WIFI_SSID='your-wifi-ssid'
WIFI_PSK='your-wifi-password'