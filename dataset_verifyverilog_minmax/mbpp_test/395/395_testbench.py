import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_non_repeat(dut):
    # Generate 50MHz clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    test_cases = [
        ("abcabc", 0),  # Longer than 8 -> becomes "abcabc" (6), expected None -> 0
        ("abc", 'a'),   # Becomes "abc   " (ignore spaces)
        ("ababc", 'c'),
        ("aabbcc", 0),  # No non-repeating char
        ("abcdabcd", 0) # Exactly 8 chars
    ]

    passed = 0
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    for input_str, expected in test_cases:
        # Pad to 8 characters with spaces
        padded = input_str.ljust(8)[:8]

        # Load characters into input vector
        for i in range(8):
            dut.str[i].value = ord(padded[i])

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait 17 cycles (0-16)
        for _ in range(17):
            await RisingEdge(dut.clk)

        # Check result
        if isinstance(expected, str):
            exp_val = ord(expected)
        else:
            exp_val = expected
        
        if dut.result.value == exp_val:
            passed += 1
            dut._log.info(f"PASS: '{input_str}' -> {chr(dut.result.value) if dut.result.value !=0 else None}")
        else:
            actual = chr(dut.result.value) if dut.result.value != 0 else None
            dut._log.error(f"FAIL: '{input_str}' -> {actual}, expected {chr(exp_val) if exp_val!=0 else None}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)