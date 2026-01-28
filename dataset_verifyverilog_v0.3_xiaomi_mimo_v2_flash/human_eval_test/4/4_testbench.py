import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper function to check for valid values (not X or Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to convert float to Q16.16 fixed point
def float_to_q16_16(f):
    return int(f * 65536)

# Helper to convert Q16.16 to float
def q16_16_to_float(q):
    return q / 65536.0

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_mean_absolute_deviation(dut):
    """Test MAD calculation for various datasets"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.count.value = 0
    for i in range(8):
        dut.numbers[i].value = 0
    
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases adapted from the Python problem
    # Inputs are Q16.16 fixed point
    test_cases = [
        ([1.0, 2.0, 3.0], 0.666667),      # 2.0/3.0
        ([1.0, 2.0, 3.0, 4.0], 1.0),
        ([1.0, 2.0, 3.0, 4.0, 5.0], 1.2), # 6.0/5.0
    ]
    
    dut._log.info("Starting MAD tests...")
    
    for i, (input_floats, expected_float) in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}: Input={input_floats}, Expected={expected_float}")
        
        # Convert inputs to fixed point
        input_q = [float_to_q16_16(f) for f in input_floats]
        expected_q = float_to_q16_16(expected_float)
        
        # Load inputs
        dut.count.value = len(input_q)
        for idx, val in enumerate(input_q):
            dut.numbers[idx].value = val
            dut._log.info(f"  numbers[{idx}] = {val} ({input_floats[idx]})")
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout_cycles = 300
        done_found = False
        for cycle in range(timeout_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined (X/Z)")
            
        result_q = int(dut.result.value)
        result_float = q16_16_to_float(result_q)
        
        # Compare (allow small tolerance for fixed-point errors)
        tolerance = 0.005
        diff = abs(result_float - expected_float)
        
        if diff > tolerance:
            raise TestFailure(f"Test {i+1}: Result mismatch. Expected {expected_float} ({expected_q}), got {result_float} ({result_q}). Diff: {diff}")
        
        dut._log.info(f"Test {i+1} passed: Result {result_float} matches expected {expected_float}")
        
        # Clear inputs for next test
        dut.count.value = 0
        for idx in range(8):
            dut.numbers[idx].value = 0
        await RisingEdge(dut.clk)
    
    dut._log.info("All 3 tests passed!")
