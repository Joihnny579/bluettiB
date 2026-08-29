import asyncio
import unittest
from types import SimpleNamespace

from custom_components.bluetti_b.switch import BluettiSwitch
from custom_components.bluetti_b.bluetti_bt_lib.utils.device_builder import build_device


class DummyClient:
    def __init__(self):
        self.is_connected = True
        self.writes = []

    async def connect(self):
        self.is_connected = True

    async def disconnect(self):
        self.is_connected = False

    async def write_gatt_char(self, uuid, payload):
        self.writes.append((uuid, bytes(payload)))


class DummyReader:
    def __init__(self, response):
        self.client = DummyClient()
        self.persistent_conn = False
        self.polling_lock = asyncio.Lock()
        self._response = response

    async def _async_send_command(self, command):
        return self._response


class TestSwitchStateVerify(unittest.IsolatedAsyncioTestCase):
    async def test_read_expected_state_reads_single_register(self):
        device = build_device("aa:bb:cc:dd:ee:ff", "AC200M123456")
        reader = DummyReader(b"\x01\x03\x02\x00\x01\x00\x00")

        switch = object.__new__(BluettiSwitch)
        switch._bluetti_device = device
        switch._coordinator = SimpleNamespace(reader=reader)
        switch._client = reader.client
        switch._polling_lock = reader.polling_lock
        switch._response_key = "ac_output_on_switch"
        switch._address = "aa:bb:cc:dd:ee:ff"

        self.assertTrue(await switch._wait_for_state(True, retries=1, delay=0))


if __name__ == "__main__":
    unittest.main()
