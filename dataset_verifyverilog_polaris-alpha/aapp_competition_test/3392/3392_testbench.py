import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import numpy as np

@cocotb.test()
async def test_max_tree_group(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1 (adapted to 4x4)
    test_input = {
        "h": [[1,2,3,0], [3,2,2,0], [5,2,1,0], [0,0,0,0]],
        "v": [[3,2,1,0], [1,2,1,0], [1,2,3,0], [0,0,0,0]]
    }
    expected = 7

    # Load inputs
    for i in range(16):
        row = i // 4
        col = i % 4
        if row < 4 and col < 3:
            dut.h_matrix[i].value = test_input["h"][row][col]
            dut.v_matrix[i].value = test_input["v"][row][col]
        else:
            dut.h_matrix[i].value = 0
            dut.v_matrix[i].value = 0

    # Start processing
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for completion
    for _ in range(350):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        assert False, "Timeout waiting for done"

    # Verify result
    assert dut.max_group_size.value == expected, f"Test1: Expected {expected}, got {dut.max_group_size.value.integer}"

    # Test Case 2 (original N=2)
    test_input = {
        "h": [[3,1], [3,3]],
        "v": [[2,5], [2,5]]
    }
    expected = 3

    # Load inputs (pad to 4x4)
    h_flat = []
    v_flat = []
    for row in test_input["h"]:
        h_flat.extend(row + [0,0])
    for row in test_input["v"]:
        v_flat.extend(row + [0,0])
    h_flat += [0]*8
    v_flat += [0]*8

    for i in range(16):
        dut.h_matrix[i].value = h_flat[i]
        dut.v_matrix[i].value = v_flat[i]

    # Start processing
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for completion
    for _ in range(350):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        assert False, "Timeout waiting for done"

    # Verify result
    assert dut.max_group_size.value == expected, f"Test2: Expected {expected}, got {dut.max_group_size.value.integer}"

    dut._log.info("2/2 tests passed")