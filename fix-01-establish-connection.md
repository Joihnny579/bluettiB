# Task: make the reader connect via `establish_connection()` (Fix #1)

## Background / why we're doing this

This integration (`bluetti_b`, a fork of hassio-bluetti-bt pinned to the 0.1.6
base) intermittently fails to read the Bluetti AC200MAX with:

    No backend with an available connection slot that can reach address C6:45:5B:84:63:7A

We diagnosed this from a Home Assistant Bluetooth **diagnostics export**, and it
is NOT genuine slot exhaustion:

- The adapter `hci0` reports **5 total connection slots, 5 free, 0 allocated**
  in steady state. Other BLE devices are advertisement-only (`Connected: False`),
  so they are not holding active connections.
- Lifetime counters: 2384 successful connects, only 15 failures.

The real cause is how this integration connects. HA logs this warning **~21000
times**, originating from `device_reader.py`:

    C6:45:5B:84:63:7A: BleakClient.connect() called without bleak-retry-connector.
    For reliable connection establishment, use bleak_retry_connector.establish_connection().

The reader calls **raw `BleakClient.connect()`**, which bypasses HA's
`bleak-retry-connector` / `habluetooth` slot management. `establish_connection()`
is the sanctioned path: it reserves a connection slot, connects with proper
backoff/retry, and **releases the slot cleanly even on failure**. Raw `.connect()`
does not coordinate with the slot manager, which produces the transient
"no available connection slot" failures even though the pool is essentially empty.

**Goal of this task:** replace the raw-connect logic in the reader with
`bleak_retry_connector.establish_connection()`, so reads become reliable and the
warning disappears. This is independent of, and comes *before*, the later
toggle-verify work.

## Files involved

- `custom_components/bluetti_b/bluetti_bt_lib/bluetooth/device_reader.py`
  — `DeviceReader.read_data()` contains the connect loop to replace. (The inner
  library folder is still named `bluetti_bt_lib`; only the integration domain
  folder was renamed to `bluetti_b`.)
- `custom_components/bluetti_b/coordinator.py`
  — `PollingCoordinator.__init__` currently builds the client and passes it to
  `DeviceReader`. This is where the device is resolved from the address.

## Current behaviour (what to change)

In `coordinator.py`, the client is built **once** at init and passed in:

```python
device = bluetooth.async_ble_device_from_address(hass, address)   # fetched ONCE
client = BleakClient(device)
self.reader = DeviceReader(client, bluetti_device, self.hass.loop.create_future, ...)
```

In `device_reader.py`, `read_data()` connects with raw `.connect()` in a manual
retry loop:

```python
for attempt in range(1, self.max_retries + 1):
    try:
        if not self.client.is_connected:
            await self.client.connect()      # <-- raw connect, the problem
        break
    except Exception as e:
        ...
        await asyncio.sleep(2)
```

The same `self.client` is then used for `start_notify`, `write_gatt_char`,
`stop_notify`, and `disconnect` (in the `finally` block, when not persistent).

## Required change

Connect through `establish_connection()` using a **freshly resolved** BLE device
each time (do not reuse a device object cached at init — stale device references
are part of the problem).

Recommended shape:

1. Stop pre-building the `BleakClient` in `coordinator.py`. Instead give the
   reader a way to resolve a fresh, connectable BLE device on demand — following
   the existing pattern of passing `self.hass.loop.create_future` as a callable.
   For example pass a getter:

   ```python
   # coordinator.py
   self.reader = DeviceReader(
       device_getter=lambda: bluetooth.async_ble_device_from_address(
           hass, address, connectable=True
       ),
       bluetti_device=bluetti_device,
       future_builder_method=self.hass.loop.create_future,
       persistent_conn=persistent_conn,
       polling_timeout=polling_timeout,
       max_retries=max_retries,
   )
   ```

   (Keep `self.address` on the coordinator; `_async_update_data`'s existing
   `async_address_present` guard stays as-is.)

2. In `device_reader.py`, import and use `establish_connection`, replacing the
   manual connect loop. Resolve the device via the getter, bail cleanly if it's
   `None`, then establish:

   ```python
   from bleak_retry_connector import establish_connection, BleakClientWithServiceCache

   device = self.device_getter()
   if device is None:
       _LOGGER.warning("Device not currently available")
       return None

   self.client = await establish_connection(
       BleakClientWithServiceCache,
       device,
       device.name or self.address or "Bluetti",
       max_attempts=self.max_retries,
   )
   ```

   `establish_connection` already does its own ret/backoff, so the old
   `for attempt in range(...)` loop and its `asyncio.sleep(2)` should be removed
   (don't wrap establish_connection in a second manual retry loop).

3. Preserve everything else:
   - The `polling_lock`, the notifier attach (`start_notify` / `has_notifier`),
     the command loop, and pack polling stay the same.
   - The `finally` block that disconnects when `not self.persistent_conn` stays.
     After a non-persistent disconnect, make sure `has_notifier` is reset so the
     next poll re-attaches the notifier on the new client.
   - For `persistent_conn=True`, reuse the existing client while it's connected;
     only call `establish_connection` again when it's disconnected.
   - Consider registering a `disconnected_callback` on `establish_connection` that
     clears `has_notifier`, so state stays correct on unexpected drops.

## Reference implementation (proven upstream)

The newer upstream code already uses this exact approach in its switch write path
(`main` branch, `switch.py`). Mirror this pattern:

```python
from bleak_retry_connector import BleakClientWithServiceCache, establish_connection
...
device = await BleakScanner.find_device_by_address(self._address, timeout=5)
if device is None:
    return
client = await establish_connection(
    BleakClientWithServiceCache,
    device,
    device.name or "Unknown Device",
    max_attempts=10,
)
```

Note: prefer HA's `bluetooth.async_ble_device_from_address(hass, address,
connectable=True)` (used via the coordinator's getter) over
`BleakScanner.find_device_by_address`, because it uses HA's central scanner data
and works with Bluetooth proxies too. The `establish_connection(...)` call itself
is identical.

## Constraints

- Do NOT regress the read path — it currently works when it manages to connect;
  the only change is *how* it connects.
- `bleak_retry_connector` is bundled with Home Assistant's bluetooth stack and is
  importable. If an import error appears at runtime, add `bleak-retry-connector`
  to `requirements` in `manifest.json`.
- Keep the change minimal and focused on the connect path. The AC/DC
  toggle-verify improvement is a **separate, later task** — do not attempt it here.
- Work on the `ac200max` branch, commit in small steps, and bump the `version` in
  `manifest.json` (e.g. to `0.1.1`) so the running build is identifiable in logs.

## How to verify (done by the human on the Pi, not in this repo)

After deploying and restarting Home Assistant with debug logging on
(`custom_components.bluetti_b: debug`, `habluetooth: debug`):

1. The warning `BleakClient.connect() called without bleak-retry-connector` from
   `device_reader.py` should **no longer appear**.
2. `No backend with an available connection slot ...` errors should stop (or drop
   dramatically), and polls should return data instead of
   `Data from coordinator is None`.
3. Entities should populate reliably at the polling interval.

If those hold, Fix #1 is successful and we move on to the toggle-verify task.
