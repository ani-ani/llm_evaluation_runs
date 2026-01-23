import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper to check if value is defined (not X/Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to convert signed integer to 2's complement representation for assignment
def to_twos_complement(val, bits=16):
    if val < 0:
        return (1 << bits) + val
    return val

# Helper to convert 2's complement to signed integer for reading
def from_twos_complement(val, bits=16):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_extrema_finder(dut):
    """Test the extrema_finder module."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases
    # Each tuple: (description, input_list, expected_largest_neg, expected_smallest_pos)
    # Values are Python ints. We will convert to 2's complement for assignment if needed.
    # Expected values are Python ints (None maps to -32768 which is 0x8000)
    test_cases = [
        ([2, 4, 1, 3, 5, 7], None, 1),
        ([2, 4, 1, 3, 5, 7, 0], None, 1),
        ([1, 3, 2, 4, 5, 6, -2], -2, 1),
        ([4, 5, 3, 6, 2, 7, -7], -7, 2),
        ([7, 3, 8, 4, 9, 2, 5, -9], -9, 2),
        ([], None, None),
        ([0], None, None),
        ([-1, -3, -5, -6], -1, None),
        ([-1, -3, -5, -6, 0], -1, None),
        ([-6, -4, -4, -3, 1], -3, 1),
        ([-6, -4, -4, -3, -100, 1], -3, 1)
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, exp_neg, exp_pos) in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}: {input_list}")
        
        # Fill array
        length = len(input_list)
        dut.len.value = length
        
        # Clear array first (or just overwrite valid indices)
        for j in range(8):
            dut.arr[j].value = 0
            
        for j, val in enumerate(input_list):
            dut.arr[j].value = to_twos_complement(val, 16)
            
        # Start pulse
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with cycle-based timeout
        max_cycles = 20
        done_received = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            # Check for X/Z
            if not is_value_defined(dut.done.value):
                continue
            if dut.done.value == 1:
                done_received = True
                break
        
        if not done_received:
            dut._log.error(f"Test {i+1} FAILED: Done signal not asserted within {max_cycles} cycles")
            failed += 1
            continue
            
        # Read results
        if not is_value_defined(dut.largest_neg.value) or not is_value_defined(dut.smallest_pos.value):
            dut._log.error(f"Test {i+1} FAILED: Output signals undefined (X/Z)")
            failed += 1
            continue
            
        raw_neg = int(dut.largest_neg.value)
        raw_pos = int(dut.smallest_pos.value)
        
        act_neg = from_twos_complement(raw_neg, 16)
        act_pos = from_twos_complement(raw_pos, 16)
        
        # Map None expectation
        expected_neg = -32768 if exp_neg is None else exp_neg
        expected_pos = -32768 if exp_pos is None else exp_pos
        
        if act_neg == expected_neg and act_pos == expected_pos:
            passed += 1
        else:
            dut._log.error(f"Test {i+1} FAILED: Input={input_list}, Expected ({exp_neg}, {exp_pos}), Got ({act_neg}, {act_pos})")
            failed += 1
            
    dut._log.info(f"Summary: {passed}/{len(test_cases)} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
