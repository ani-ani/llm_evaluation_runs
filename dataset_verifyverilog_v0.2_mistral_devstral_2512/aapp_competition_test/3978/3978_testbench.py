import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_paint_the_numbers(dut):
    """Test the paint_the_numbers module with various test cases"""
    
    # Create a 10MHz clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.data_in.value = 0
    dut.num_inputs.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases
    # Format: (num_inputs, [list of inputs], expected_colors)
    test_cases = [
        (6, [10, 2, 3, 5, 4, 2], 3),
        (4, [100, 100, 100, 100], 1),
        (8, [7, 6, 5, 4, 3, 2, 2, 3], 4),
        (1, [1], 1),
        (1, [100], 1),
        (2, [1, 2], 1),
        (5, [40, 80, 40, 40, 40], 1)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (n, inputs, expected) in enumerate(test_cases):
        # Start sequence
        await RisingEdge(dut.clk)
        dut.start.value = 1
        dut.num_inputs.value = n
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed inputs
        for val in inputs:
            dut.valid_in.value = 1
            dut.data_in.value = val
            await RisingEdge(dut.clk)
        
        dut.valid_in.value = 0
        
        # Wait for completion (with timeout)
        max_cycles = 25000
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Test case {idx+1}: Timeout waiting for done signal")
        
        # Check result
        result = int(dut.num_colors.value)
        if result == expected:
            passed += 1
            print(f"Test case {idx+1} passed: {inputs} -> {result} colors")
        else:
            print(f"Test case {idx+1} FAILED: {inputs} -> Expected {expected}, Got {result}")
            # Don't raise failure, just report for benchmarking
            
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
