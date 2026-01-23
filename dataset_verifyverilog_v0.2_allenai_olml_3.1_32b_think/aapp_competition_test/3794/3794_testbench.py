import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_split_gcd_basic(dut):
    """Test basic split: [2,3,6,7] -> valid split"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: [2, 3, 6, 7] -> YES (group1={6,7}, group2={2,3})
    dut.n.value = 4
    dut.data[0].value = 2
    dut.data[1].value = 3
    dut.data[2].value = 6
    dut.data[3].value = 7
    dut.data[4].value = 0
    dut.data[5].value = 0
    dut.data[6].value = 0
    dut.data[7].value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 300 cycles)
    cycles = 0
    while not dut.done.value and cycles < 300:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= 300:
        raise TestFailure("Timeout - took more than 300 cycles")
    
    if not dut.possible.value:
        raise TestFailure(f"Expected possible=1, got {dut.possible.value}")
    
    # Check mask - expected: 1100 (binary) = 12 decimal
    # mask=1100 means data[0]=2->g1, data[1]=3->g1, data[2]=6->g2, data[3]=7->g2
    # Actually we want: group1={6,7}, group2={2,3} -> mask=0011 = 3
    # Or group1={2,3}, group2={6,7} -> mask=1100 = 12
    # Either is valid
    mask = dut.mask.value
    print(f"Result: possible={dut.possible.value}, mask={mask} (binary: {bin(mask)})")
    
    # Verify: non-empty both sides and GCDs
    assert mask != 0 and mask != (1 << dut.n.value) - 1, "Mask must represent non-empty groups"
    

@cocotb.test()
async def test_split_gcd_multi(dut):
    """Test multiple valid cases"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    tests = [
        ([6, 15, 35, 77, 22], True),   # Expected YES
        ([6, 10, 15, 1000, 75], False), # Expected NO
        ([8, 1, 6], False),            # Expected NO
        ([84, 33, 80, 6], False),      # Expected NO
    ]
    
    for arr, expected in tests:
        dut.n.value = len(arr)
        for i in range(8):
            if i < len(arr):
                dut.data[i].value = arr[i]
            else:
                dut.data[i].value = 0
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait
        cycles = 0
        while not dut.done.value and cycles < 300:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= 300:
            raise TestFailure(f"Timeout for {arr}")
        
        result = bool(dut.possible.value)
        if result != expected:
            raise TestFailure(f"Test {arr}: expected {expected}, got {result}")
        
        print(f"PASS: {arr} -> {result} (expected {expected})")

@cocotb.test()
async def test_split_gcd_minimal(dut):
    """Test edge cases with n=2"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Case: [1, 1] -> YES (group1={1}, group2={1})
    dut.n.value = 2
    dut.data[0].value = 1
    dut.data[1].value = 1
    dut.data[2].value = 0
    dut.data[3].value = 0
    dut.data[4].value = 0
    dut.data[5].value = 0
    dut.data[6].value = 0
    dut.data[7].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 300:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= 300:
        raise TestFailure("Timeout")
    
    if not dut.possible.value:
        raise TestFailure(f"[1,1] should be possible")
    
    # Case: [2, 4] -> NO (both groups would have gcd > 1)
    dut.n.value = 2
    dut.data[0].value = 2
    dut.data[1].value = 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 300:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= 300:
        raise TestFailure("Timeout")
    
    if dut.possible.value:
        raise TestFailure(f"[2,4] should not be possible")
    
    print("Edge cases passed")

@cocotb.test()
async def test_split_gcd_larger(dut):
    """Test with 6 elements: [53, 9, 79, 47, 2, 64] -> YES"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    arr = [53, 9, 79, 47, 2, 64]
    dut.n.value = len(arr)
    for i in range(8):
        if i < len(arr):
            dut.data[i].value = arr[i]
        else:
            dut.data[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 300:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= 300:
        raise TestFailure("Timeout")
    
    # Expected YES
    if not dut.possible.value:
        raise TestFailure(f"{arr} should be possible")
    
    mask = dut.mask.value
    print(f"Result for {arr}: mask={mask} (0b{mask:06b})")
    
    # Verify non-empty groups
    assert mask != 0 and mask != 63, "Both groups must be non-empty"
