import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_power(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    test_cases = [
        # (x, n, expected)
        (16, 2, 1),    # 2^4 = 16
        (4, 2, 1),     # 2^2 = 4
        (9, 3, 1),     # 3^2 = 9
        (24, 2, 0),    # No integer power
        (128, 4, 0),   # 4^3=64 < 128, 4^4=256>128
        (1, 1, 1),     # Edge case
        (1, 5, 1),     # 5^0 = 1
        (65536, 2, 0)  # Exceeds 16-bit range
    ]

    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    for x_val, n_val, expected in test_cases:
        # Skip test if x exceeds 16-bit range
        if x_val > 0xFFFF:
            continue

        dut.x.value = x_val
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: x={x_val}, n={n_val} => {expected}")
        else:
            dut._log.error(f"FAIL: x={x_val}, n={n_val} => {dut.result.value}, expected {expected}")

        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"