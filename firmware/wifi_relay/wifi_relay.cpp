// Wi-Fi relay client: see wifi_relay.h. Compiled only into the *_wifi envs.
#ifdef WIFI_RELAY

#include "wifi_relay.h"

#include <Arduino.h>
#include <HTTPClient.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>

#include "isrg_roots.h"

#if __has_include("wifi_secrets.h")
#include "wifi_secrets.h"
#else
#error "Copy wifi_relay/wifi_secrets.example.h to wifi_relay/wifi_secrets.h and fill it in"
#endif

#define POLL_MS       60000  // relay caches 60 s, so faster polling gains nothing
#define RETRY_MS      15000  // after a failed poll: retry soon, before the screen goes stale
#define BLE_FRESH_MS  90000  // daemon delivered within this window → skip Wi-Fi
#define BUF_SIZE      512    // same as BLE_BUF_SIZE; payloads are ~250 bytes

static char shared_buf[BUF_SIZE];  // written by the task, guarded by mux
static char main_buf[BUF_SIZE];    // handed to main loop by get_data()
static volatile bool ready = false;
static volatile uint32_t last_ble_ms = 0;
static volatile bool ble_seen = false;
static portMUX_TYPE mux = portMUX_INITIALIZER_UNLOCKED;

static bool fetch_once(void) {
    WiFiClientSecure client;
    client.setCACert(ISRG_ROOTS_PEM);  // verify the server: Let's Encrypt roots only
    HTTPClient http;
    http.setTimeout(10000);
    if (!http.begin(client, RELAY_URL)) {
        Serial.println("WIFI: bad RELAY_URL");
        return false;
    }
    int code = http.GET();
    bool ok = false;
    if (code == 200) {
        String body = http.getString();
        if (body.length() < BUF_SIZE) {
            portENTER_CRITICAL(&mux);
            memcpy(shared_buf, body.c_str(), body.length() + 1);
            ready = true;
            portEXIT_CRITICAL(&mux);
            ok = true;
            Serial.printf("WIFI: got %u bytes, free heap %u\n", body.length(), ESP.getFreeHeap());
        } else {
            Serial.printf("WIFI: payload too large (%u)\n", body.length());
        }
    } else {
        // <0 = transport/TLS error, 503 = relay has no data (token problem)
        Serial.printf("WIFI: GET failed: %d %s\n", code, http.errorToString(code).c_str());
    }
    http.end();
    return ok;
}

// Why a connect failed: is the SSID visible on 2.4 GHz, on which channel, with what auth
static void scan_for_ssid(void) {
    WiFi.setAutoReconnect(false);  // a pending connect attempt makes the scan fail (-2)
    WiFi.disconnect();
    delay(500);
    int n = WiFi.scanNetworks();
    Serial.printf("WIFI: scan: %d networks on 2.4 GHz, looking for '%s'\n", n, WIFI_SSID);
    for (int i = 0; i < n; i++) {
        Serial.printf("WIFI:   %s'%s' ch %d RSSI %d auth %d\n",
                      WiFi.SSID(i) == WIFI_SSID ? "-> " : "   ", WiFi.SSID(i).c_str(),
                      WiFi.channel(i), WiFi.RSSI(i), (int)WiFi.encryptionType(i));
    }
    WiFi.scanDelete();
    WiFi.setAutoReconnect(true);
    WiFi.begin(WIFI_SSID, WIFI_PASS);
}

// Own task, so a slow TLS handshake never stalls the UI loop
static void relay_task(void*) {
    uint32_t last_poll = 0;
    uint32_t interval = POLL_MS;
    bool first = true;
    bool was_connected = false;
    bool scanned = false;
    for (;;) {
        if (!scanned && !was_connected && millis() > 20000 && WiFi.status() != WL_CONNECTED) {
            scanned = true;
            scan_for_ssid();
        }
        bool connected = WiFi.status() == WL_CONNECTED;
        if (connected != was_connected) {
            was_connected = connected;
            if (connected) Serial.printf("WIFI: connected, IP %s, RSSI %d\n",
                                         WiFi.localIP().toString().c_str(), WiFi.RSSI());
            else           Serial.println("WIFI: disconnected (auto-reconnecting)");
        }
        bool due = first || millis() - last_poll >= interval;
        bool ble_fresh = ble_seen && millis() - last_ble_ms < BLE_FRESH_MS;
        if (connected && due) {
            if (ble_fresh) {
                Serial.println("WIFI: skip poll, daemon is delivering over BLE");
            } else {
                interval = fetch_once() ? POLL_MS : RETRY_MS;
            }
            last_poll = millis();
            first = false;
        }
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void wifi_relay_init(void) {
    WiFi.onEvent([](arduino_event_id_t, arduino_event_info_t info) {
        // reason codes: 2 auth expired, 15 4-way handshake timeout (wrong password),
        // 201 no AP found, 202 auth fail, 204 handshake timeout
        Serial.printf("WIFI: disconnected, reason %d\n", info.wifi_sta_disconnected.reason);
    }, ARDUINO_EVENT_WIFI_STA_DISCONNECTED);
    WiFi.mode(WIFI_STA);
    WiFi.setAutoReconnect(true);
    // Modem sleep stays on (default): required while BLE shares the radio
    WiFi.begin(WIFI_SSID, WIFI_PASS);
    Serial.printf("WIFI: connecting to %s\n", WIFI_SSID);
    xTaskCreate(relay_task, "wifi_relay", 8192, nullptr, 1, nullptr);
}

bool wifi_relay_has_data(void) {
    return ready;
}

const char* wifi_relay_get_data(void) {
    portENTER_CRITICAL(&mux);
    memcpy(main_buf, shared_buf, BUF_SIZE);
    ready = false;
    portEXIT_CRITICAL(&mux);
    return main_buf;
}

void wifi_relay_note_ble_data(void) {
    last_ble_ms = millis();
    ble_seen = true;
}

#endif  // WIFI_RELAY
