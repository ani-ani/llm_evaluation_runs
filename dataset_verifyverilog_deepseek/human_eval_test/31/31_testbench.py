import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_is_prime(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        (1, 0),
        (2, 1),
        (3, 1),
        (4, 0),
        (5, 1),
        (6, 0),
        (11, 1),
        (17, 1),
        (61, 1),
        (101, 1),
        (85, 0),  # 5*17
        (77, 0),  # 11*7
        # Removed 13441*19 (exceeds 16 bits)
    ]

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    total = len(test_cases)

    for n, expected in test_cases:
        # Apply inputs
        dut.n.value = n
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for ready
        while (dut.ready.value != 1):
            await RisingEdge(dut.clk)

        # Check result
        result = dut.is_prime.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n} is_prime={result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: n={n} got {result}, expected {expected}")
        
        await RisingEdge(dut.clk)

    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")