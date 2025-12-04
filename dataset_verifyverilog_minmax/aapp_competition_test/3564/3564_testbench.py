import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_tunnel(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    # Test case 1: Expected output 1400
    test1_islands = [
        (0, 0, 400), (1000, 0, 400), (2000, 0, 400)
    ]
    test1_trees = [
        (300, 0, 150), (1300, 0, 150)
    ]
    test1_k = 3
    # Test case 2: Expected impossible
    test2_islands = [
        (0, 0, 400), (1000, 0, 400), (2000, 0, 400)
    ]
    test2_trees = [
        (300, 0, 100), (1300, 0, 100)
    ]
    test2_k = 2
    test_cases = [
        (test1_islands, test1_trees, test1_k, 1400, False),
        (test2_islands, test2_trees, test2_k, 0, True)
    ]
    passed = 0
    for islands, trees, k_val, exp_length, exp_impossible in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        # Load input data
        dut.n_islands.value = len(islands)
        dut.n_trees.value = len(trees)
        dut.k.value = k_val
        for i in range(8):
            if i < len(islands):
                dut.island_x[i].value = islands[i][0] * 100  # convert to cm
                dut.island_y[i].value = islands[i][1] * 100
                dut.island_r[i].value = islands[i][2] * 100
            else:
                dut.island_x[i].value = 0
                dut.island_y[i].value = 0
                dut.island_r[i].value = 0
        for i in range(16):
            if i < len(trees):
                dut.tree_x[i].value = trees[i][0] * 100
                dut.tree_y[i].value = trees[i][1] * 100
                dut.tree_h[i].value = trees[i][2] * 100
            else:
                dut.tree_x[i].value = 0
                dut.tree_y[i].value = 0
                dut.tree_h[i].value = 0
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        # Check results
        if dut.impossible.value == exp_impossible and (exp_impossible or dut.tunnel_length.value == exp_length):
            passed += 1
        else:
            dut._log.error("Test failed: Expected (%d, %s) Got (%d, %s)" % (
                exp_length, str(exp_impossible), dut.tunnel_length.value, "True" if dut.impossible.value else "False"))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))