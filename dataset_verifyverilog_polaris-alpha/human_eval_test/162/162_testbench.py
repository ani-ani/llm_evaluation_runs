import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import hashlib

@cocotb.test()
async def test_md5(dut):
    # Setup clock (100MHz)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # MD5 padding helper function
    def md5_pad(msg_bytes):
        orig_len = len(msg_bytes) * 8
        msg_bytes += b'\\x80'
        while (len(msg_bytes) % 64) not in [56, 0]:
            msg_bytes += b'\\x00'
        msg_bytes += orig_len.to_bytes(8, 'little')
        return int.from_bytes(msg_bytes, 'little')

    # Generate test cases
    test_data = [
        (b'Hello world', '3e25960a79dbc69b674cd4ec67a72c62'),
        (b'', 'd41d8cd98f00b204e9800998ecf8427e'),
        (b'A B C', '0ef78513b0cb8cef12743f5aeb35f888'),
        (b'password', '5f4dcc3b5aa765d61d8327deb882cf99')
    ]

    # Pad messages and convert to 512-bit vectors
    test_cases = []
    for data, expected in test_data:
        padded_blk = md5_pad(data)
        expected_int = int(expected, 16)
        test_cases.append((padded_blk, expected_int, data))

    # Initialize
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for blk, expected_hash, orig_msg in test_cases:
        # Load input
        dut.blk.value = blk
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait 64 cycles for computation
        for _ in range(65):
            await RisingEdge(dut.clk)

        # Check result
        if dut.done.value != 1:
            dut._log.error(f"Done signal not set after 65 cycles for '{orig_msg}'")
        elif dut.hash.value == expected_hash:
            passed += 1
            dut._log.info(f"PASS: '{orig_msg}' -> 0x{dut.hash.value.integer:032x}")
        else:
            dut._log.error(f"FAIL: '{orig_msg}' -> 0x{dut.hash.value.integer:032x}, expected 0x{expected_hash:032x}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)