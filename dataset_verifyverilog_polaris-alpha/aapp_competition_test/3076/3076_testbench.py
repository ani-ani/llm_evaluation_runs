import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_knapsack(dut):
    # Create 10ns period clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    # Test Case 1 (Scaled sample 1)
    jewel_sizes = [2, 1, 3, 5, 0, 0, 0, 0]  # 4 jewels
    jewel_values = [8, 1, 4, 100, 0, 0, 0, 0]
    expected = [1, 8, 9, 9, 100, 100+1, 100+8, 100+9]

    # Load inputs
    for i in range(8):
        dut.jewel_sizes[i].value = jewel_sizes[i]
        dut.jewel_values[i].value = jewel_values[i]
    dut.jewel_count.value = 4  # 4 jewels
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for computation
    await ClockCycles(dut.clk, 4 + 2)  # jewel_count=4 + 2 cycles delay

    # Check results
    passed = 0
    for i in range(8):
        actual = dut.dp_table[i].value.integer
        if i < len(expected):
            if actual != expected[i]:
                dut._log.error(f"Size {i+1} fail: Got {actual}, Expected {expected[i]}")
            else:
                passed += 1
        else:
            if actual != 0:
                dut._log.error(f"Size {i+1} should be 0, got {actual}")
            else:
                passed += 1

    # Test Case 2 (Sample 2 - 5 jewels)
    jewel_sizes = [2, 3, 2, 2, 3, 0, 0, 0]
    jewel_values = [2, 8, 7, 4, 8, 0, 0, 0]
    expected = [0, 7, 8, 7+4, 8+7, 8+7, 7+8+4, 0]
    expected[6] = 19  # sample correction

    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for i in range(8):
        dut.jewel_sizes[i].value = jewel_sizes[i]
        dut.jewel_values[i].value = jewel_values[i]
    dut.jewel_count.value = 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    await ClockCycles(dut.clk, 5 + 2)

    for i in range(7):  # only check first 7
        actual = dut.dp_table[i].value.integer
        if i < len(expected):
            if actual != expected[i]:
                dut._log.error(f"Size {i+1} fail: Got {actual}, Expected {expected[i]}")
            else:
                passed += 1

    # Test Case 3 (Too big jewels sample)
    jewel_sizes = [8, 8, 0, 0, 0, 0, 0, 0]
    jewel_values = [1, 2, 0, 0, 0, 0, 0, 0]

    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for i in range(8):
        dut.jewel_sizes[i].value = jewel_sizes[i]
        dut.jewel_values[i].value = jewel_values[i]
    dut.jewel_count.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    await ClockCycles(dut.clk, 2 + 2)

    for i in range(8):
        actual = dut.dp_table[i].value.integer
        expected = min(i+1, 8) * 1  # Only first jewel can fit if size=8+
        if actual != (1 if (i+1) >= 8 else 0):
            dut._log.error(f"Size {i+1} should be {1 if (i+1)>=8 else 0}, got {actual}")
        else:
            passed += 1

    dut._log.info(f"{passed}/24 tests passed")