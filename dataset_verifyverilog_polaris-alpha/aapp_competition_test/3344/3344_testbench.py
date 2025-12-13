import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

# Q16.16 conversion functions
def float_to_q16_16(f):
    return int(f * (1 << 16)) % (1 << 32)

def q16_16_to_float(q):
    return q / (1 << 16) if q < 0x80000000 else (q - 0x100000000) / (1 << 16)

@cocotb.test()
async def luggage_speed_test(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        # Sample Input 1
        {"L": 3.0, "positions": [0.0, 2.0], "expected": 2.0},
        # Sample Input 2
        {"L": 4.0, "positions": [0.05, 1.0, 3.5], "expected": 0.5},
        # Edge case: no solution
        {"L": 1.0, "positions": [0.0, 0.5], "expected": "no fika"},
        # 8 items case
        {"L": 16.0, "positions": [0.0,1.5,3.0,5.1,7.2,9.3,11.4,15.9], "expected": 1.333}
    ]

    passed = 0
    for case in test_cases:
        # Load inputs
        dut.L_fixed.value = float_to_q16_16(case["L"])
        for i in range(8):
            pos = case["positions"][i] if i < len(case["positions"]) else 0.0
            dut.positions[i].value = float_to_q16_16(pos)
        dut.num_items.value = len(case["positions"])

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Verify outputs
        if case["expected"] == "no fika":
            if dut.valid.value == 0:
                passed += 1
            else:
                dut._log.error(f"NO FIKA CASE FAILED: Got valid speed {q16_16_to_float(dut.speed_fixed.value.value)}")
        else:
            expected_val = float_to_q16_16(case["expected"])
            actual_val = dut.speed_fixed.value
            tolerance = 10 # Allow 10 quanta difference (~0.0001526)
            if abs(actual_val - expected_val) <= tolerance and dut.valid.value == 1:
                passed += 1
            else:
                dut._log.error(f"Test failed: Expected {case["expected"]} ({hex(expected_val)}), got {q16_16_to_float(actual_val)} ({hex(actual_val)})")

        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
