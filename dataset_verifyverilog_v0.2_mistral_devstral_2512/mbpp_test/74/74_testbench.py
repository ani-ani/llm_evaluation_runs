import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

# Helper function to convert string to 64-bit ASCII value
def str_to_64bit(s):
    if len(s) > 8:
        raise ValueError(f"String {s} too long")
    val = 0
    for i, c in enumerate(s):
        val |= (ord(c) << (i*8))
    return val

@cocotb.test()
async def test_pattern_match_same(dut):
    """Test case 1: Same pattern - should return 0 (pass)"""
    # Setup
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid.value = 0
    dut.last.value = 0
    dut.index.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: ["red","green","green"] vs ["a", "b", "b"]
    # Sequence length = 3
    test_data = [
        (0, "a", "red", False),
        (1, "b", "green", False),
        (2, "b", "green", True)
    ]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for idx, pat, col, is_last in test_data:
        dut.index.value = idx
        dut.patterns_i.value = str_to_64bit(pat)
        dut.colors_i.value = str_to_64bit(col)
        dut.valid.value = 1
        dut.last.value = 1 if is_last else 0
        await RisingEdge(dut.clk)
    
    dut.valid.value = 0
    dut.last.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 20:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if not dut.done.value:
        raise TestFailure("Test 1: Did not complete in time")
    
    if dut.result.value != 0:
        raise TestFailure(f"Test 1: Expected result=0 (pass), got {dut.result.value}")
    
    print("Test 1 passed: Same pattern detected correctly")

@cocotb.test()
async def test_pattern_mismatch_color(dut):
    """Test case 2: Different colors for same pattern - should return 1 (fail)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid.value = 0
    dut.last.value = 0
    dut.index.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: ["red","green","greenn"] vs ["a","b","b"] - pattern 'b' maps to 'green' and 'greenn'
    test_data = [
        (0, "a", "red", False),
        (1, "b", "green", False),
        (2, "b", "greenn", True)
    ]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for idx, pat, col, is_last in test_data:
        dut.index.value = idx
        dut.patterns_i.value = str_to_64bit(pat)
        dut.colors_i.value = str_to_64bit(col)
        dut.valid.value = 1
        dut.last.value = 1 if is_last else 0
        await RisingEdge(dut.clk)
    
    dut.valid.value = 0
    dut.last.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 20:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if not dut.done.value:
        raise TestFailure("Test 2: Did not complete in time")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 2: Expected result=1 (fail), got {dut.result.value}")
    
    print("Test 2 passed: Mismatch detected correctly")

@cocotb.test()
async def test_length_mismatch(dut):
    """Test case 3: Different sequence lengths - should return 1 (fail)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid.value = 0
    dut.last.value = 0
    dut.index.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: ["red","green","greenn"] vs ["a","b"] (length mismatch)
    # Even with valid data, module should detect length mismatch
    # We'll feed 2 elements, but last flag triggers verification
    test_data = [
        (0, "a", "red", False),
        (1, "b", "green", True)  # Last element, length=2 vs expected 3
    ]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for idx, pat, col, is_last in test_data:
        dut.index.value = idx
        dut.patterns_i.value = str_to_64bit(pat)
        dut.colors_i.value = str_to_64bit(col)
        dut.valid.value = 1
        dut.last.value = 1 if is_last else 0
        await RisingEdge(dut.clk)
    
    dut.valid.value = 0
    dut.last.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 20:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if not dut.done.value:
        raise TestFailure("Test 3: Did not complete in time")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 3: Expected result=1 (fail), got {dut.result.value}")
    
    print("Test 3 passed: Length mismatch detected correctly")

@cocotb.test()
async def test_pattern_reverse_mapping(dut):
    """Test case 4: Two different patterns mapping to same color (should fail)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid.value = 0
    dut.last.value = 0
    dut.index.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: ["red","green","green"] vs ["a","b","c"] - b and c both map to green
    test_data = [
        (0, "a", "red", False),
        (1, "b", "green", False),
        (2, "c", "green", True)
    ]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for idx, pat, col, is_last in test_data:
        dut.index.value = idx
        dut.patterns_i.value = str_to_64bit(pat)
        dut.colors_i.value = str_to_64bit(col)
        dut.valid.value = 1
        dut.last.value = 1 if is_last else 0
        await RisingEdge(dut.clk)
    
    dut.valid.value = 0
    dut.last.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 20:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if not dut.done.value:
        raise TestFailure("Test 4: Did not complete in time")
    
    # According to problem logic, this should FAIL because len(pset)=3, len(sset)=2
    if dut.result.value != 1:
        raise TestFailure(f"Test 4: Expected result=1 (fail due to different set sizes), got {dut.result.value}")
    
    print("Test 4 passed: Reverse mapping mismatch detected")

@cocotb.test()
async def test_single_element(dut):
    """Test case 5: Single element - always matches"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid.value = 0
    dut.last.value = 0
    dut.index.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Single element: ["red"] vs ["a"]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.index.value = 0
    dut.patterns_i.value = str_to_64bit("a")
    dut.colors_i.value = str_to_64bit("red")
    dut.valid.value = 1
    dut.last.value = 1
    await RisingEdge(dut.clk)
    
    dut.valid.value = 0
    dut.last.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 20:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if not dut.done.value:
        raise TestFailure("Test 5: Did not complete in time")
    
    if dut.result.value != 0:
        raise TestFailure(f"Test 5: Expected result=0 (pass), got {dut.result.value}")
    
    print("Test 5 passed: Single element case")
    print("All tests completed!")