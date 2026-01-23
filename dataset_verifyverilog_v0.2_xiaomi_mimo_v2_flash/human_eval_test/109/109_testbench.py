import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_move_one_ball(dut):
    """Test the move_one_ball module with various test cases"""
    
    # Setup clock (50MHz)
    clock = Clock(dut.clk, 20, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.arr.value = [0]*8
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [3, 4, 5, 1, 2] -> True (1 drop at position 2: 5>1)
    # Fill remaining 3 positions with dummy values that don't affect
    # We'll use 8 elements: [3, 4, 5, 1, 2, 6, 7, 8] -> has 2 drops (5>1, 2<6 is fine, 8>3 is another)
    # Better: [3, 4, 5, 1, 2, 3, 4, 5] -> drops: 5>1, 5>3, still multiple
    # Let's use: [3, 4, 5, 1, 2, 6, 7, 8] -> 8>3 is a drop, but 5>1 is also a drop
    # Actually, for 8 elements, we need a single drop
    # Example: [1, 2, 3, 4, 5, 6, 7, 0] -> 7>0 is one drop, rest are sorted
    # After shifts: [0,1,2,3,4,5,6,7] sorted
    # Let's test with 5 elements: [3,4,5,1,2] scaled to 8 with padded zeros
    # Use: [3,4,5,1,2,6,7,8] doesn't work
    # Use: [0,1,2,3,4,5,7,6] -> 7>6 is one drop
    # Better approach: test with 8 element examples
    
    # Test 1: Already sorted array [1,2,3,4,5,6,7,8]
    dut.arr.value = [1,2,3,4,5,6,7,8]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for computation (8 cycles for processing)
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 1 failed: expected 1, got {dut.result.value}")
    print("Test 1 passed: Already sorted array [1,2,3,4,5,6,7,8] returns True")
    
    # Test 2: Single drop at end [1,2,3,4,5,6,7,0] (7>0 is only drop)
    dut.arr.value = [1,2,3,4,5,6,7,0]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 2 failed: expected 1, got {dut.result.value}")
    print("Test 2 passed: [1,2,3,4,5,6,7,0] (single drop 7>0) returns True")
    
    # Test 3: Multiple drops [4,3,1,2] -> scale to 8: [4,3,1,2,5,6,7,8]
    # Drops: 4>3, 3>1, 2<5, 7<8, 8>4 (circular) -> multiple drops
    dut.arr.value = [4,3,1,2,5,6,7,8]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.result.value != 0:
        raise TestFailure(f"Test 3 failed: expected 0, got {dut.result.value}")
    print("Test 3 passed: [4,3,1,2,5,6,7,8] (multiple drops) returns False")
    
    # Test 4: Single drop in middle [3,4,5,1,2,6,7,8] -> drops: 5>1, 8>3 (circular)
    # This has 2 drops, so False
    # Use [2,3,4,5,6,7,8,1] -> 8>1 is one drop, rest sorted
    dut.arr.value = [2,3,4,5,6,7,8,1]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 4 failed: expected 1, got {dut.result.value}")
    print("Test 4 passed: [2,3,4,5,6,7,8,1] (single drop 8>1) returns True")
    
    # Test 5: All same value (but unique requirement, so use descending with single drop)
    # Use [8,1,2,3,4,5,6,7] -> 8>1, 7<8 circular? 7<8 no, but 8>1 yes
    # Circular: 7 to 8: 7<8, 8 to 1: 8>1 (one drop)
    dut.arr.value = [8,1,2,3,4,5,6,7]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 5 failed: expected 1, got {dut.result.value}")
    print("Test 5 passed: [8,1,2,3,4,5,6,7] (single drop 8>1) returns True")
    
    # Test 6: Two drops [3,5,4,1,2,6,7,8] -> 5>4, 8>3, 4>1 (multiple)
    dut.arr.value = [3,5,4,1,2,6,7,8]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.result.value != 0:
        raise TestFailure(f"Test 6 failed: expected 0, got {dut.result.value}")
    print("Test 6 passed: [3,5,4,1,2,6,7,8] (multiple drops) returns False")
    
    # Test 7: Empty array (all zeros) - our 8-element representation
    # For "empty" we can interpret as already sorted (all zeros)
    dut.arr.value = [0,0,0,0,0,0,0,0]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 7 failed: expected 1, got {dut.result.value}")
    print("Test 7 passed: Empty/all zeros returns True")
    
    print("
All 7/7 tests passed!")
