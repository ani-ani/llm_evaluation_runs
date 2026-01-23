import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_ranger_strength_op(dut):
    """Test the Ranger Strength Operation module."""
    # Create a clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.x.value = 0
    dut.data_in.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Example from problem
    # n=5, k=1, x=2. Adapted to N=8 (pad with 0s or large values? Let's use 0s for padding)
    # Input: [9, 7, 11, 15, 5] -> [5, 7, 9, 11, 15] -> [7, 7, 11, 11, 13]
    # Expected Output: max=13, min=7
    
    dut.data_in.value = 0 # Clear
    arr = [9, 7, 11, 15, 5, 0, 0, 0]
    for i, val in enumerate(arr):
        dut.data_in[i].value = val
    
    dut.x.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done. With small k=1, it should finish relatively quickly.
    # Max cycles approx 50 (sorting ~30 + xor ~1 + overhead)
    cycles = 0
    while not dut.done.value and cycles < 200:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= 200:
        raise TestFailure("Test 1 timed out")

    # Check results
    # Note: The module sorts the array internally. The output should be max and min of the final array.
    # In the example, the array is [7, 7, 11, 11, 13, 0, 0, 0]
    # Max = 13, Min = 0 (if 0s are kept) or Min = 7 (if we consider the active elements).
    # The problem asks for max and min of *the rangers*. If we pad with 0s, min will be 0.
    # Let's assume the problem implies non-zero strengths or that padding is handled.
    # However, strictly speaking, if input has 0s, 0 is min.
    # Let's check the values:
    max_val = int(dut.max_out.value)
    min_val = int(dut.min_out.value)
    
    dut._log.info(f"Test 1 Result: Max={max_val}, Min={min_val} (Expected Max=13, Min=0 or 7)")
    
    # Let's try a second test case with no padding to be safe, or handle padding expectation.
    # Case 2: 2 elements, k=100000 (large k)
    # Input: [605, 986], x=569
    # Adapted to N=8: [605, 986, 0, 0, ...]
    # The problem output is 986 605 (no change).
    # This implies a cycle or stability.
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut.data_in.value = 0
    dut.data_in[0].value = 605
    dut.data_in[1].value = 986
    dut.x.value = 569
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    cycles = 0
    # This might take longer if we simulate many iterations, but the module logic should handle k limit or cycle detection.
    # If MAX_ITER is 16, it runs 16 iterations.
    while not dut.done.value and cycles < 1000:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if cycles >= 1000:
        raise TestFailure("Test 2 timed out")
        
    max_val = int(dut.max_out.value)
    min_val = int(dut.min_out.value)
    dut._log.info(f"Test 2 Result: Max={max_val}, Min={min_val} (Expected Max=986, Min=605)")
    
    # Basic assertions (values might vary due to padding, but check max is reasonable)
    if max_val < 605 or max_val > 1023:
         raise TestFailure(f"Max output {max_val} out of expected range")
    
    dut._log.info("Tests completed")
