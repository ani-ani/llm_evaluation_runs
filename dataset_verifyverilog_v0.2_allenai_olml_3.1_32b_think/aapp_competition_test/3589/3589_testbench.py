import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_digit_product_distribution(dut):
    """Test digit product distribution computation"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.L.value = 0
    dut.R.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: 3 to 7
    # Expected: 0 0 1 1 1 1 1 0 0
    dut.L.value = 3
    dut.R.value = 7
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 65536 cycles * 10 cycles = 655us, but small range is faster)
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test case 1: Timeout waiting for done")
    
    result = dut.result.value
    # Extract counts: result[3:0]=a1, result[7:4]=a2, ..., result[35:32]=a9
    # But result is 16-bit, so we need to check interpretation
    # For small range, expect: a3=1, a4=1, a5=1, a6=1, a7=1
    # Convert to individual nibbles
    counts = [(result >> (4*i)) & 0xF for i in range(9)]
    print(f"Test 1 (3-7): {counts}")
    
    # Verify: 0,0,1,1,1,1,1,0,0
    expected = [0,0,1,1,1,1,1,0,0]
    for i in range(9):
        if counts[i] != expected[i]:
            raise TestFailure(f"Count a{i+1} mismatch: got {counts[i]}, expected {expected[i]}")
    
    # Test Case 2: 50 to 100
    # Expected: 3 7 4 6 5 7 2 15 2
    # Note: Our 16-bit result truncates counts > 15, but this range has counts up to 15
    dut.L.value = 50
    dut.R.value = 100
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 20000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 20000:
        raise TestFailure("Test case 2: Timeout waiting for done")
    
    result = dut.result.value
    counts = [(result >> (4*i)) & 0xF for i in range(9)]
    print(f"Test 2 (50-100): {counts}")
    
    # Expected: [3,7,4,6,5,7,2,15,2]
    # Note: a8=15 is exactly 4 bits, fits in nibble
    expected = [3,7,4,6,5,7,2,15,2]
    for i in range(9):
        if counts[i] != expected[i]:
            raise TestFailure(f"Count a{i+1} mismatch: got {counts[i]}, expected {expected[i]}")
    
    # Test Case 3: Single number 8
    # 8 -> 8, so a8=1
    dut.L.value = 8
    dut.R.value = 8
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test case 3: Timeout")
    
    result = dut.result.value
    counts = [(result >> (4*i)) & 0xF for i in range(9)]
    print(f"Test 3 (8): {counts}")
    
    # 8 maps to a8=1
    if counts[7] != 1:
        raise TestFailure(f"a8 should be 1 for input 8, got {counts[7]}")
    
    print("All tests passed!")
