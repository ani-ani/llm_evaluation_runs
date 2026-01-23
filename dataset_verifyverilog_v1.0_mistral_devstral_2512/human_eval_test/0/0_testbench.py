import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper function to convert decimal to Q16.16 format
def to_q16_16(value):
    return int(value * 65536) & 0xFFFFFFFF

# Helper function to check if value is defined (not X or Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper function to wait for combinational propagation
async def wait_for_settle(dut):
    await Timer(50, units='ns')

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_has_close_elements(dut):
    """Test has_close_elements module with various test cases"""
    
    # Generate clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.threshold.value = 0
    dut.arr_0.value = 0
    dut.arr_1.value = 0
    dut.arr_2.value = 0
    dut.arr_3.value = 0
    dut.arr_4.value = 0
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases adapted for Q16.16 format and 8-element array
    # Format: (description, array_values, threshold_value, expected_result)
    test_cases = [
        ("Test 1: [1.0, 2.0, 3.9, 4.0, 5.0, 2.2] with threshold 0.3 -> True",
         [1.0, 2.0, 3.9, 4.0, 5.0, 2.2, 0.0, 0.0], 0.3, True),
        
        ("Test 2: [1.0, 2.0, 3.9, 4.0, 5.0, 2.2] with threshold 0.05 -> False",
         [1.0, 2.0, 3.9, 4.0, 5.0, 2.2, 0.0, 0.0], 0.05, False),
        
        ("Test 3: [1.0, 2.0, 5.9, 4.0, 5.0] with threshold 0.95 -> True",
         [1.0, 2.0, 5.9, 4.0, 5.0, 0.0, 0.0, 0.0], 0.95, True),
        
        ("Test 4: [1.0, 2.0, 5.9, 4.0, 5.0] with threshold 0.8 -> False",
         [1.0, 2.0, 5.9, 4.0, 5.0, 0.0, 0.0, 0.0], 0.8, False),
        
        ("Test 5: [1.0, 2.0, 3.0, 4.0, 5.0, 2.0] with threshold 0.1 -> True",
         [1.0, 2.0, 3.0, 4.0, 5.0, 2.0, 0.0, 0.0], 0.1, True),
        
        ("Test 6: [1.1, 2.2, 3.1, 4.1, 5.1] with threshold 1.0 -> True",
         [1.1, 2.2, 3.1, 4.1, 5.1, 0.0, 0.0, 0.0], 1.0, True),
        
        ("Test 7: [1.1, 2.2, 3.1, 4.1, 5.1] with threshold 0.5 -> False",
         [1.1, 2.2, 3.1, 4.1, 5.1, 0.0, 0.0, 0.0], 0.5, False),
        
        ("Edge case: All same values, threshold 0.1 -> False",
         [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0], 0.1, False),
        
        ("Edge case: Close pair at end, threshold 0.1 -> True",
         [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 7.05], 0.1, True),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (description, array_vals, threshold_val, expected) in enumerate(test_cases):
        dut._log.info(f"\nRunning: {description}")
        
        # Convert to Q16.16 and assign values
        threshold_q16 = to_q16_16(threshold_val)
        dut.threshold.value = threshold_q16
        
        # Assign array values
        dut.arr_0.value = to_q16_16(array_vals[0])
        dut.arr_1.value = to_q16_16(array_vals[1])
        dut.arr_2.value = to_q16_16(array_vals[2])
        dut.arr_3.value = to_q16_16(array_vals[3])
        dut.arr_4.value = to_q16_16(array_vals[4])
        dut.arr_5.value = to_q16_16(array_vals[5])
        dut.arr_6.value = to_q16_16(array_vals[6])
        dut.arr_7.value = to_q16_16(array_vals[7])
        
        await wait_for_settle(dut)
        
        # Pulse start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with timeout
        max_cycles = 50
        done_received = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_received = True
                break
        
        if not done_received:
            raise TestFailure(f"Test {i+1}: Done signal not received within {max_cycles} cycles")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result has undefined value (X/Z)")
        
        result = int(dut.result.value)
        expected_val = 1 if expected else 0
        
        if result == expected_val:
            dut._log.info(f"Test {i+1} PASSED: Result={result}, Expected={expected_val}")
            passed += 1
        else:
            raise TestFailure(f"Test {i+1} FAILED: Result={result}, Expected={expected_val}")
        
        # Wait for done to go low
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")
    dut._log.info(f"{'='*50}")
    
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")
