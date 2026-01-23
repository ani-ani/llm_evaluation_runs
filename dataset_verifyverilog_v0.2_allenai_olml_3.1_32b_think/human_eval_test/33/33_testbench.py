import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def sort_third_py(l):
    """Python reference implementation"""
    result = l.copy()
    # Get indices divisible by 3 within range
    indices = [i for i in range(len(l)) if i % 3 == 0]
    # Extract values at these indices
    values = [l[i] for i in indices]
    # Sort the values
    values.sort()
    # Place sorted values back
    for idx, val in zip(indices, values):
        result[idx] = val
    return result

def fixed_to_int(val, bits=8):
    """Convert signed 8-bit integer to Python int"""
    if val >= (1 << (bits-1)):
        return val - (1 << bits)
    return val

def int_to_fixed(val, bits=8):
    """Convert Python int to signed 8-bit representation"""
    if val < 0:
        return (1 << bits) + val
    return val & ((1 << bits) - 1)

@cocotb.test()
async def test_sort_third(dut):
    """Test sort_third module with various inputs"""
    
    # Create and start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases from Python problem
    test_cases = [
        [1, 2, 3],
        [5, 6, 3, 4, 8, 9, 2],
        [5, 8, -12, 4, 23, 2, 3, 11],
        [5, 6, 3, 4, 8, 9, 2, 1],
        [5, 3, -5, 2, -3, 3, 9, 0],
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, test_input in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: Input = {test_input}")
        
        # Pad to 8 elements if needed
        if len(test_input) < 8:
            test_input_padded = test_input + [0] * (8 - len(test_input))
        else:
            test_input_padded = test_input[:8]
        
        # Get Python reference result (only first 8 elements)
        expected_full = sort_third_py(test_input_padded)
        
        # Load input array
        for idx in range(8):
            val = int_to_fixed(test_input_padded[idx])
            dut.data_in[idx].value = val
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout = 50
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            dut._log.error(f"Test {i+1} timed out!")
            continue
        
        # Read results
        result = []
        for idx in range(8):
            val = fixed_to_int(int(dut.data_out[idx].value))
            result.append(val)
        
        # Compare
        expected = expected_full[:8]
        
        # For display, show only the relevant part of original input
        original_len = len(test_input)
        result_display = result[:original_len]
        expected_display = expected[:original_len]
        
        if result_display == expected_display:
            dut._log.info(f"  PASS: Got {result_display}, Expected {expected_display}")
            passed += 1
        else:
            dut._log.error(f"  FAIL: Got {result_display}, Expected {expected_display}")
            # Show internal state for debugging
            dut._log.info(f"  Full 8-element result: {result}")
            dut._log.info(f"  Full 8-element expected: {expected}")
    
    dut._log.info(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
