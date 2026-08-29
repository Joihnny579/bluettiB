# Bluetti BT — AC200MAX fork

Personal fork of the `hassio-bluetti-bt` Home Assistant integration
(upstream: Patrick762/hassio-bluetti-bt), pinned to the **0.1.6** tag.
Working branch: `ac200max`.

## Why 0.1.6 (do not "upgrade" to 0.2.x)

- 0.2.x cannot discover the Bluetti **AC200MAX**. Its rewritten config flow
  only adds a device through automatic Bluetooth discovery, which calls a
  `recognize_device()` probe (in the separately pip-installed `bluetti-bt-lib`)
  to read IoT-module version / encryption. The AC200MAX is an older,
  non-encrypted, v1-protocol unit and doesn't answer that probe, so discovery
  aborts. The manual device-picker fallback that 0.1.6 had was removed.
- 0.1.6 works: it discovers the AC200MAX and reads live values correctly.
- 0.1.6 is **self-contained** — the whole `bluetti_bt_lib` ships as editable
  local files under `custom_components/bluetti_bt/`, no pip dependency. This is
  what makes it hackable.

Trade-off accepted: this is an upstream dead-end. Changes won't merge back and
we forgo future updates. That's fine for a personal build.

## The device

- Bluetti AC200MAX, **Bluetooth-only**, handles **one BT connection at a time**.
- Normal polling should stay **non-persistent** (connect → read → disconnect)
  so the phone / Bluetti app can still connect between polls. Target poll
  interval ~300s.

## Goal of this fork

Make the AC/DC on-off **control** reliable on the AC200MAX.

Current behaviour in `custom_components/bluetti_bt/switch.py` → `write_to_device`:
sends the setter command on `self._client`, sleeps 5s, disconnects (when
non-persistent), then calls `coordinator.async_request_refresh()` — which opens
a **second** connection to read state back. That second connect is the fragile
step on the AC200MAX's touchy BT controller; when it fails, the toggle looks
like it didn't work even though the write succeeded.

Desired behaviour: on a toggle, connect once, write, then **read the relevant
register back on the same still-open connection**, retrying a few times until it
reflects the requested state (or a bounded max), and only then disconnect.
"Connect immediately, hold the connection until verified, then release it" —
without making normal polling persistent.

Before writing code: confirm how the reader exposes a single-field read and
whether `persistent_conn` / the field register are reachable from the switch.
Read `switch.py`, `coordinator.py`, and the reader in `bluetti_bt_lib/` first
and report findings before changing anything.

## Key files

- `custom_components/bluetti_bt/switch.py` — the control entities; `write_to_device` is the main edit target.
- `custom_components/bluetti_bt/coordinator.py` — `PollingCoordinator` (HA DataUpdateCoordinator), `_async_update_data`, holds the reader + `persistent_conn`.
- `custom_components/bluetti_bt/bluetti_bt_lib/` — bundled library:
  - `bluetooth/device_reader.py` — connect/read logic.
  - `base_devices/BluettiDevice.py` — `build_setter_command`, field defs.
  - `field_attributes.py`, `const.py` (`WRITE_UUID`), `utils/device_builder.py`.
- `custom_components/bluetti_bt/manifest.json` — bump `version` to e.g. `0.1.6-mine` to identify this build in logs.

## Conventions

- Work on branch `ac200max`. Commit in small, reversible steps.
- Keep the **read path intact** — it already works; don't regress it.
- Minimal, targeted changes. Prefer editing `write_to_device` (+ a small
  read-one-field helper) over broad refactors.

## Out of scope for Claude Code (done by the human, separately)

- No access to the running Home Assistant / Raspberry Pi from here.
- Cannot capture HA debug logs or test toggles on the physical device.
- Python changes require a **full HA restart** to load; there is no hot-reload.
- Deployment to the Pi and on-device debug-log capture happen outside this repo.
