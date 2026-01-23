import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_mul_even_odd(dut):
    """Test mul_even_odd module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize signals
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = [0] * 8
    
    # Reset
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: [1,3,5,7,4,1,6,8] -> first_even=4, first_odd=1, product=4
    print("
Test 1: [1,3,5,7,4,1,6,8]")
    dut.data_in.value = [1, 3, 5, 7, 4, 1, 6, 8]
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    print(f"Result: {result}, Expected: 4")
    assert result == 4, f"Test 1 failed: got {result}, expected 4"
    
    # Wait for idle
    await RisingEdge(dut.clk)
    
    # Test 2: [1,2,3,4,5,6,7,8,9,10] -> first_even=2, first_odd=1, product=2
    print("
Test 2: [1,2,3,4,5,6,7,8,9,10] (first 8 elements: [1,2,3,4,5,6,7,8])")
    dut.data_in.value = [1, 2, 3, 4, 5, 6, 7, 8]
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    print(f"Result: {result}, Expected: 2")
    assert result == 2, f"Test 2 failed: got {result}, expected 2"
    
    await RisingEdge(dut.clk)
    
    # Test 3: [1,5,7,9,10] -> first_even=10, first_odd=1, product=10
    print("
Test 3: [1,5,7,9,10] (padded with zeros)")
    dut.data_in.value = [1, 5, 7, 9, 10, 0, 0, 0]
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    print(f"Result: {result}, Expected: 10")
    assert result == 10, f"Test 3 failed: got {result}, expected 10"
    
    await RisingEdge(dut.clk)
    
    # Test 4: No even numbers [1,3,5,7,9,11,13,15] -> output 0xFFFF
    print("
Test 4: [1,3,5,7,9,11,13,15] - no even numbers")
    dut.data_in.value = [1, 3, 5, 7, 9, 11, 13, 15]
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    print(f"Result: {result}, Expected: 65535 (0xFFFF)")
    assert result == 65535, f"Test 4 failed: got {result}, expected 65535"
    
    await RisingEdge(dut.clk)
    
    # Test 5: No odd numbers [2,4,6,8,10,12,14,16] -> output 0xFFFF
    print("
Test 5: [2,4,6,8,10,12,14,16] - no odd numbers")
    dut.data_in.value = [2, 4, 6, 8, 10, 12, 14, 16]
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    print(f"Result: {result}, Expected: 65535 (0xFFFF)")
    assert result == 65535, f"Test 5 failed: got {result}, expected 65535"
    
    print("
=== All tests passed! ===")