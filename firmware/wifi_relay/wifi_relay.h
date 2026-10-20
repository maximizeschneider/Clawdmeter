#pragma once
// Wi-Fi relay client (env *_wifi, -DWIFI_RELAY): polls relay/relay.py over HTTPS
// so the display keeps updating while the Mac daemon is off. BLE stays fully on
// (HID keys, daemon data); a fresh BLE payload pauses Wi-Fi polling.

void wifi_relay_init(void);
// Same contract as ble_has_data()/ble_get_data(): has_data() is true once per
// new payload; get_data() returns it as a NUL-terminated JSON string.
bool wifi_relay_has_data(void);
const char* wifi_relay_get_data(void);
// Call on every BLE payload: while the daemon delivers, Wi-Fi polling pauses.
void wifi_relay_note_ble_data(void);
