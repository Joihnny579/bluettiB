# Changelog

## 0.1.10
### Fixed
- BLE "No backend with an available connection slot" errors caused by a
  slot leak: `establish_connection()` was run inside the polling
  `async_timeout` and got cancelled mid-connect, so HA's slot manager
  never released the allocation. Connection is now established outside the
  timeout and the slot is always released (see device_reader.read_data).
- AttributeError crash in sensor/binary_sensor/switch
  `_handle_coordinator_update` when persistent connection was enabled but
  `reader.client` was still None. Added a None-guard.
### Changed
- scripts/release.sh can now publish a real GitHub Release (HACS requires
  Releases, not just tags) via the new `--publish` flag.
