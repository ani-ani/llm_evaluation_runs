import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_last_position_search(dut):
    """Test the last_position_search module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.target.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Test Case 1: arr=[1,2,3], target=1 ===")
    # Expected: position 0
    dut.arr[0].value = 1
    dut.arr[1].value = 2
    dut.arr[2].value = 3
    dut.arr[3].value = 3
    dut.arr[4].value = 3
    dut.arr[5].value = 3
    dut.arr[6].value = 3
    dut.arr[7].value = 3
    dut.target.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 0, f"Test 1 failed: expected 0, got {dut.result.value}"
    print(f"Test 1 passed: result={dut.result.value}")
    
    # Wait for next cycle
    await RisingEdge(dut.clk)
    
    print("
=== Test Case 2: arr=[1,1,1,2,3,4], target=1 ===")
    # Expected: position 2
    dut.arr[0].value = 1
    dut.arr[1].value = 1
    dut.arr[2].value = 1
    dut.arr[3].value = 2
    dut.arr[4].value = 3
    dut.arr[5].value = 4
    dut.arr[6].value = 4
    dut.arr[7].value = 4
    dut.target.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 2, f"Test 2 failed: expected 2, got {dut.result.value}"
    print(f"Test 2 passed: result={dut.result.value}")
    
    await RisingEdge(dut.clk)
    
    print("
=== Test Case 3: arr=[2,3,2,3,6,8,9], target=3 ===")
    # Note: Array must be sorted for binary search to work
    # This test case is actually invalid (unsorted)
    # Using correct sorted version: [2,2,3,3,6,8,9]
    # Expected: position 3
    dut.arr[0].value = 2
    dut.arr[1].value = 2
    dut.arr[2].value = 3
    dut.arr[3].value = 3
    dut.arr[4].value = 6
    dut.arr[5].value = 8
    dut.arr[6].value = 9
    dut.arr[7].value = 9
    dut.target.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 3, f"Test 3 failed: expected 3, got {dut.result.value}"
    print(f"Test 3 passed: result={dut.result.value}")
    
    await RisingEdge(dut.clk)
    
    print("
=== Test Case 4: Element not found ===")
    # arr=[1,3,5,7,9,11,13,15], target=2
    # Expected: 7 (sentinel for not found)
    dut.arr[0].value = 1
    dut.arr[1].value = 3
    dut.arr[2].value = 5
    dut.arr[3].value = 7
    dut.arr[4].value = 9
    dut.arr[5].value = 11
    dut.arr[6].value = 13
    dut.arr[7].value = 15
    dut.target.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 7, f"Test 4 failed: expected 7, got {dut.result.value}"
    print(f"Test 4 passed: result={dut.result.value} (sentinel)")
    
    await RisingEdge(dut.clk)
    
    print("
=== Test Case 5: Target at end of array ===")
    # arr=[1,2,3,4,5,6,7,8], target=8
    # Expected: position 7
    dut.arr[0].value = 1
    dut.arr[1].value = 2
    dut.arr[2].value = 3
    dut.arr[3].value = 4
    dut.arr[4].value = 5
    dut.arr[5].value = 6
    dut.arr[6].value = 7
    dut.arr[7].value = 8
    dut.target.value = 8
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 7, f"Test 5 failed: expected 7, got {dut.result.value}"
    print(f"Test 5 passed: result={dut.result.value}")
    
    print("
=== All tests completed ===")