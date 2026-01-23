import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_tree_shopping(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.tree_heights.value = [0] * 8
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Example 1 (Adapted)
    # Original: 10 2
    # 1 3 5 7 9 11 13 15 17 16 -> Min diff is 1
    # Adapted for n=8, k=3: Trees [1, 3, 5, 7, 9, 11, 13, 15]
    # Windows: 
    # [1,3,5] -> max=5, min=1, diff=4
    # [3,5,7] -> max=7, min=3, diff=4
    # [5,7,9] -> max=9, min=5, diff=4
    # [7,9,11] -> max=11, min=7, diff=4
    # [9,11,13] -> max=13, min=9, diff=4
    # [11,13,15] -> max=15, min=11, diff=4
    # Result should be 4
    trees1 = [1, 3, 5, 7, 9, 11, 13, 15]
    dut.tree_heights.value = trees1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 100, "Timeout waiting for done"
    assert dut.min_diff.value == 4, f"Expected 4, got {dut.min_diff.value}"
    print(f"Test 1 Passed: Min diff = {dut.min_diff.value}")

    await RisingEdge(dut.clk)

    # Test Case 2: Example 2 (Adapted)
    # Original: 5 4
    # 1 1 3 5 6 -> Min diff is 4
    # Adapted for n=8, k=3: 
    # Trees: [1, 1, 3, 5, 6, 0, 0, 0] (padding zeros)
    # Windows:
    # [1,1,3] -> max=3, min=1, diff=2
    # [1,3,5] -> max=5, min=1, diff=4
    # [3,5,6] -> max=6, min=3, diff=3
    # [5,6,0] -> max=6, min=0, diff=6
    # [6,0,0] -> max=6, min=0, diff=6
    # Result should be 2
    trees2 = [1, 1, 3, 5, 6, 0, 0, 0]
    dut.tree_heights.value = trees2
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 100, "Timeout waiting for done"
    assert dut.min_diff.value == 2, f"Expected 2, got {dut.min_diff.value}"
    print(f"Test 2 Passed: Min diff = {dut.min_diff.value}")

    # Test Case 3: Edge case with duplicate values
    trees3 = [5, 5, 5, 5, 5, 5, 5, 5]
    dut.tree_heights.value = trees3
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.min_diff.value == 0, f"Expected 0, got {dut.min_diff.value}"
    print(f"Test 3 Passed: Min diff = {dut.min_diff.value}")
    print("All tests passed!")