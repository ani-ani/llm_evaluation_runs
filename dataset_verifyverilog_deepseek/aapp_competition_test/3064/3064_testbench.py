import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_longest_path(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (scaled to 6 nodes max)
    test_cases = [
        (
            4,  # nodes
            [
                (0,1), (0,2), (1,3)  # Sample 1
            ],
            2   # expected
        ),
        (
            6,  # nodes
            [
                (0,1), (0,2), (1,3), (2,3), (2,4), (4,5)  # Sample 2
            ],
            5   # expected
        ),
        (
            5,  # nodes
            [
                (0,1), (1,2), (2,3), (3,4), (4,2), (2,0)  # Sample 3
            ],
            6   # expected
        )
    ]

    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for nodes, edges, expected in test_cases:
        # Reset edge memory
        dut.edges.value = 0
        for i, (a, b) in enumerate(edges):
            # Format: 3-bit A + 3-bit B + 2'b00
            dut.edges.value[i*8 + 7:i*8] = (a << 5) | (b << 2)

        dut.node_count.value = nodes - 1  # 0-based count (4 nodes = value 3)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (100 cycles max)
        for _ in range(100):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            assert False, "Timeout waiting for done signal"

        if dut.path_length.value == expected:
            passed += 1
            dut._log.info(f"Test passed: {expected} == {dut.path_length.value}")
        else:
            dut._log.error(f"Test failed: Got {dut.path_length.value}, expected {expected}")

        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)