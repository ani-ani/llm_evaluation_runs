import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_minimal_settlers(dut):
    # Create 50MHz clock
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    # Test cases (scaled to 8-node max)
    # Input format encodings:
    # node_count = num cells, followed by iron_count, coal_count then
    # iron_list as bitmask, coal_list as bitmask
    # neighbor_counts and neighbors as packed arrays
    test_cases = [
        # Test case 1 (Sample input 1)
        {
            "node_count": 3,
            "iron_count": 1,
            "coal_count": 1,
            "iron_list": 0b00000010, # node 2 (index1)
            "coal_list": 0b00000100, # node 3 (index2)
            "neighbor_counts": [1, 2, 1],
            "neighbors": [[2,0,0,0], [3,1,0,0], [1,0,0,0]],
            "expected": 2,
            "impossible": 0
        },\\
        # Test case 2 (Sample input 2)
        {
            "node_count": 3,
            "iron_count": 1,
            "coal_count": 1,
            "iron_list": 0b00000010, # node 2
            "coal_list": 0b00000100, # node3
            "neighbor_counts": [1,1,2], # Note: edges must reach coal path
            "neighbors": [[2,0,0,0], [1,0,0,0], [1,2,0,0]],
            "expected": 0,
            "impossible": 1
        }
    ]

    passed = 0
    total = len(test_cases)

    for test in test_cases:
        await reset()
        dut.node_count.value = test["node_count"]
        dut.iron_count.value = test["iron_count"]
        dut.coal_count.value = test["coal_count"]
        dut.iron_list.value = test["iron_list"]
        dut.coal_list.value = test["coal_list"]

        # Set neighbor counts and lists
        for i in range(8):
            if i < test["node_count"]:
                dut.neighbor_counts[i].value = test["neighbor_counts"][i]
                for j in range(4):
                    if j < test["neighbor_counts"][i]:
                        dut.neighbors[i][j].value = test["neighbors"][i][j] - 1 # 0-based indexing
                    else:
                        dut.neighbors[i][j].value = 0
            else:
                dut.neighbor_counts[i].value = 0
                for j in range(4):
                    dut.neighbors[i][j].value = 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 50 cycles)
        for _ in range(50):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break

        if dut.done.value == 0:
            dut._log.error("Test timed out")
            continue

        # Check results
        if dut.impossible.value == test["impossible"]:
            if dut.impossible.value:
                passed += 1
            else:
                if dut.result.value == test["expected"]:
                    passed += 1
                else:
                    dut._log.error(f"Test failed: expected {test['expected']} settlers, got {int(dut.result.value)}")
        else:
            dut._log.error(f"Impossible flag mismatch: expected {test['impossible']}, got {dut.impossible.value}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
