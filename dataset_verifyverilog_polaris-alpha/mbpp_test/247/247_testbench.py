import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_lps(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (8-character strings)
    test_cases = [
        ("ABA#####", 3),  # 'ABA' padded (LPS=3)
        ("AAB######", 2), # 'AAB' padded (LPS=2)
        ("ABCBA###", 5), # 'ABCBA' padded (LPS=5)
        ("ABCDEFGH", 1), # All different (LPS=1)
        ("A#######", 1),  # Single character (LPS=1)
    ]

    passed = 0

    for (test_str, expected) in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load string input
        for i, char in enumerate(test_str):
            dut.str[i].value = ord(char)

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 20 cycles)
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break

        # Verify result
        if dut.lps_length.value == expected:
            passed += 1
            dut._log.info(f"PASS: '{test_str}' -> {dut.lps_length.value}")
        else:
            dut._log.error(f"FAIL: '{test_str}' -> {dut.lps_length.value}, expected {expected}")

    # Print summary
    total = len(test_cases)
    dut._log.info(f"TEST SUMMARY: {passed}/{total} passed")