import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_scary_subarray_counter(dut):
    """Test scary subarray counter with various test cases"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.array_length.value = 0
    dut.p_0.value = 0
    dut.p_1.value = 0
    dut.p_2.value = 0
    dut.p_3.value = 0
    dut.p_4.value = 0
    dut.p_5.value = 0
    dut.p_6.value = 0
    dut.p_7.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [1,2,3,4,5] -> scary count = 5
    # All singletons (5) are scary. [1,2,3] median=2 !=1, [2,3,4] median=3 !=2, etc.
    # Actually wait: [1,2,3] sorted=[1,2,3], median=2, leftmost=1 -> not scary
    # [2,3,4] median=3, leftmost=2 -> not scary
    # So only 5 singletons
    print("
Test 1: [1,2,3,4,5] expecting 5")
    dut.array_length.value = 5
    dut.p_0.value = 1
    dut.p_1.value = 2
    dut.p_2.value = 3
    dut.p_3.value = 4
    dut.p_4.value = 5
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 40 cycles)
    for _ in range(40):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted within timeout")
    
    result = int(dut.scary_count.value)
    print(f"Result: {result}")
    assert result == 5, f"Expected 5, got {result}"
    
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Test case 2: [3,2,1,6,4,5] -> expecting 8
    # Singletons: 6
    # Length 3: [3,2,1] sorted=[1,2,3], median=2, leftmost=3 -> no
    #            [2,1,6] sorted=[1,2,6], median=2, leftmost=2 -> YES
    #            [1,6,4] sorted=[1,4,6], median=4, leftmost=1 -> no
    #            [6,4,5] sorted=[4,5,6], median=5, leftmost=6 -> no
    # Length 5: [3,2,1,6,4] sorted=[1,2,3,4,6], median=3, leftmost=3 -> YES
    # So: 6 + 1 + 1 = 8
    print("
Test 2: [3,2,1,6,4,5] expecting 8")
    dut.array_length.value = 6
    dut.p_0.value = 3
    dut.p_1.value = 2
    dut.p_2.value = 1
    dut.p_3.value = 6
    dut.p_4.value = 4
    dut.p_5.value = 5
    dut.p_6.value = 0
    dut.p_7.value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(40):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted within timeout")
    
    result = int(dut.scary_count.value)
    print(f"Result: {result}")
    assert result == 8, f"Expected 8, got {result}"
    
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Test case 3: [2,1,5,3,6,7,4] -> expecting 11
    # Singletons: 7
    # Length 3: [2,1,5] median=2, leftmost=2 -> YES
    #            [1,5,3] median=3, leftmost=1 -> no
    #            [5,3,6] median=5, leftmost=5 -> YES
    #            [3,6,7] median=6, leftmost=3 -> no
    #            [6,7,4] median=6, leftmost=6 -> YES (sorted [4,6,7], median=6)
    # Length 5: [2,1,5,3,6] sorted [1,2,3,5,6], median=3, leftmost=2 -> no
    #            [1,5,3,6,7] sorted [1,3,5,6,7], median=5, leftmost=1 -> no
    #            [5,3,6,7,4] sorted [3,4,5,6,7], median=5, leftmost=5 -> YES
    # Length 7: [2,1,5,3,6,7,4] sorted [1,2,3,4,5,6,7], median=4, leftmost=2 -> no
    # So: 7 + 3 + 1 = 11
    print("
Test 3: [2,1,5,3,6,7,4] expecting 11")
    dut.array_length.value = 7
    dut.p_0.value = 2
    dut.p_1.value = 1
    dut.p_2.value = 5
    dut.p_3.value = 3
    dut.p_4.value = 6
    dut.p_5.value = 7
    dut.p_6.value = 4
    dut.p_7.value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(50):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted within timeout")
    
    result = int(dut.scary_count.value)
    print(f"Result: {result}")
    assert result == 11, f"Expected 11, got {result}"
    
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Test case 4: [5,4,3,2,1] -> expecting 5
    # All singletons scary. No other scary subarrays because leftmost is largest.
    print("
Test 4: [5,4,3,2,1] expecting 5")
    dut.array_length.value = 5
    dut.p_0.value = 5
    dut.p_1.value = 4
    dut.p_2.value = 3
    dut.p_3.value = 2
    dut.p_4.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(40):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    result = int(dut.scary_count.value)
    print(f"Result: {result}")
    assert result == 5, f"Expected 5, got {result}"
    
    print("
All tests passed! 4/4")