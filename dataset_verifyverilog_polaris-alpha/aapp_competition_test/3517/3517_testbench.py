import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_critical_path(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (scaled to 4 nodes max)
    test_cases = [
        # Test 1: Original sample (2 nodes)
        {
            "node_count": 2,
            "times": [15, 20],
            "deps": [0b0000, 0b0001],  # node1: no deps, node2: depends on 1
            "expected": 15
        },
        # Test 2: Original 4-node example
        {
            "node_count": 4,
            "times": [10, 40, 70, 10],
            "deps": [0b0000, 0b0001, 0b0001, 0b0110],  # node4 deps on 2,3 (bits 1 and 2)
            "expected": 60
        },
        # Test 3: Additional 3-node case
        {
            "node_count": 3,
            "times": [30, 50, 40],
            "deps": [0b0000, 0b0001, 0b0010],  # chain: 1→2→3
            "expected": 70  # Eliminate node2 (original 30+40=70)
        }
    ]

    passed = 0
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for i, tc in enumerate(test_cases):
        # Setup inputs
        dut.node_count.value = tc["node_count"]
        for idx in range(4):
            dut.time_vals[idx].value = tc["times"][idx] if idx < tc["node_count"] else 0
            dut.deps[idx].value = tc["deps"][idx] if idx < tc["node_count"] else 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 45 cycles)
        for _ in range(45):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break

        # Verify output
        actual = dut.min_time.value.integer
        if actual == tc["expected"]:
            passed += 1
            dut._log.info(f"Test {i+1} passed")
        else:
            dut._log.error(f"Test {i+1} FAILED: Expected {tc['expected']}, got {actual}")

        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)