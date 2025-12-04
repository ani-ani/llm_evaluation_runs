import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_special_numbers(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n_bin.value = 0
    dut.k.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        (0b110, 2, 3),   # Original 6 → 3 special numbers
        (0b1111, 2, 5),  # 15 has 5 special numbers
        (0b1, 0, 1),
        (0b1000, 1, 3),  # 8 → numbers 2,4,8 need 1 op
        (0b1010, 3, 0)   # 10 → no numbers need 3 ops
    ]
    passed = 0

    for n_val, k_val, expected in test_cases:
        # Apply inputs
        dut.n_bin.value = n_val
        dut.k.value = k_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for computation
        for _ in range(25):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break

        # Check result
        actual = dut.count.value
        if actual == expected:
            passed += 1
        else:
            dut._log.error(f"FAIL: n={bin(n_val)} k={k_val} expected={expected} got={actual}")

        await Timer(10, units="ns")

    # Test summary
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total