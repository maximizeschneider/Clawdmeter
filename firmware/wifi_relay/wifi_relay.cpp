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
#define BLE_FRESH_MS  90000  // daemon delivered within this window → skip Wi-Fi
#define BUF_SIZE      512    // same as BLE_BUF_SIZE; payloads are ~250 bytes

static char shared_buf[BUF_SIZE];  // written by the task, guarded by mux
static char main_buf[BUF_SIZE];    // handed to main loop by get_data()
static volatile bool ready = false;
static volatile uint32_t last_ble_ms = 0;
static volatile bool ble_seen = false;
static portMUX_TYPE mux = portMUX_INITIALIZER_UNLOCKED;

static void fetch_once(void) {
    WiFiClientSecure client;
    client.setCACert(ISRG_ROOTS_PEM);  // verify the server: Let's Encrypt roots only
    HTTPClient http;
    http.setTimeout(10000);
    if (!http.begin(client, RELAY_URL)) {
        Serial.println("WIFI: bad RELAY_URL");
        return;
    }
    int code = http.GET();
    if (code == 200) {
        String body = http.getString();
        if (body.length() < BUF_SIZE) {
            portENTER_CRITICAL(&mux);
            memcpy(shared_buf, body.c_str(), body.length() + 1);
            ready = true;
            portEXIT_CRITICAL(&mux);
            Serial.printf("WIFI: got %u bytes, free heap %u\n", body.length(), ESP.getFreeHeap());
        } else {
            Serial.printf("WIFI: payload too large (%u)\n", body.length());
        }
    } else {
        // <0 = transport/TLS error, 503 = relay has no data (token problem)
        Serial.printf("WIFI: GET failed: %d %s\n", code, http.errorToString(code).c_str());
    }
    http.end();
}

// Own task, so a slow TLS handshake never stalls the UI loop
static void relay_task(void*) {
    uint32_t last_poll = 0;
    bool first = true;
    bool was_connected = false;
    for (;;) {
        bool connected = WiFi.status() == WL_CONNECTED;
        if (connected != was_connected) {
            was_connected = connected;
            if (connected) Serial.printf("WIFI: connected, IP %s, RSSI %d\n",
                                         WiFi.localIP().toString().c_str(), WiFi.RSSI());
            else           Serial.println("WIFI: disconnected (auto-reconnecting)");
        }
        bool due = first || millis() - last_poll >= POLL_MS;
        bool ble_fresh = ble_seen && millis() - last_ble_ms < BLE_FRESH_MS;
        if (connected && due) {
            if (ble_fresh) {
                Serial.println("WIFI: skip poll, daemon is delivering over BLE");
            } else {
                fetch_once();
            }
            last_poll = millis();
            first = false;
        }
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void wifi_relay_init(void) {
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
