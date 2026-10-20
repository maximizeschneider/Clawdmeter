#pragma once
// Copy to wifi_secrets.h (gitignored) for the *_wifi envs.
#define WIFI_SSID "your-network"   // 2.4 GHz only (ESP32 has no 5 GHz radio)
#define WIFI_PASS "your-password"
// RELAY_KEY from the relay's env file: https://<relay host>/u/<RELAY_KEY>
#define RELAY_URL "https://clawdmeter.example.com/u/RELAY_KEY"
