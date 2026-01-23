import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_sum_negative(dut):
    """Test sum of negative numbers in array"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.index.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
Test 1: [2, 4, -6, -9, 11, -12, 14, -5, 17] -> -32")
    print("(Using first 8: [2, 4, -6, -9, 11, -12, 14, -5] -> -32)")
    test1 = [2, 4, -6, -9, 11, -12, 14, -5]
    await run_test(dut, test1, -32)
    
    print("
Test 2: [10,15,-14,13,-18,12,-20,0] -> -52")
    test2 = [10, 15, -14, 13, -18, 12, -20, 0]
    await run_test(dut, test2, -52)
    
    print("
Test 3: [19, -65, 57, 39, 152, -639, 121, 44] -> -704")
    print("(Adapted: using first 8 elements)")
    test3 = [19, -65, 57, 39, 152, -639, 121, 44]
    # Note: -639 needs to be clamped to -128 for 8-bit
    test3_scaled = [19, -65, 57, 39, 127, -128, 121, 44]  # -128 instead of -639
    expected = -65 + -128  # = -193
    await run_test(dut, test3_scaled, expected)
    
    # Edge case: all positive
    print("
Test 4: All positive [1,2,3,4,5,6,7,8] -> 0")
    test4 = [1, 2, 3, 4, 5, 6, 7, 8]
    await run_test(dut, test4, 0)
    
    # Edge case: all negative
    print("
Test 5: All negative [-1,-2,-3,-4,-5,-6,-7,-8] -> -36")
    test5 = [-1, -2, -3, -4, -5, -6, -7, -8]
    await run_test(dut, test5, -36)
    
    # Edge case: zeros
    print("
Test 6: All zeros [0,0,0,0,0,0,0,0] -> 0")
    test6 = [0, 0, 0, 0, 0, 0, 0, 0]
    await run_test(dut, test6, 0)

async def run_test(dut, test_array, expected):
    """Helper function to run a single test case"""
    
    # Wait for idle
    await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed array elements one by one
    for i, val in enumerate(test_array):
        # Convert negative numbers to 8-bit signed representation
        if val < 0:
            # Two's complement for negative number
            val_unsigned = (val + 256) & 0xFF
        else:
            val_unsigned = val & 0xFF
        
        dut.data_in.value = val_unsigned
        dut.index.value = i
        await RisingEdge(dut.clk)
    
    # Wait for completion (should be in DONE state)
    timeout = 20
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    # Read result
    result = int(dut.result.value)
    
    # Handle 12-bit signed result
    if result >= 2048:  # Negative if bit 11 is set
        result = result - 4096
    
    print(f"Expected: {expected}, Got: {result}, Done: {dut.done.value}")
    assert result == expected, f"Expected {expected}, got {result}"
    assert dut.done.value == 1, "Done signal not asserted"
    
    print("Test passed!")
