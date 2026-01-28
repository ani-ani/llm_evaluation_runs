import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 16
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 150

# Helper functions
def is_value_defined(v):
    try:
        int(v); return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name); return True
    except AttributeError:
        return False

def float_to_q8_8(f):
    """Convert float to Q8.8 format (16-bit signed)"""
    # Q8.8: 8 integer bits, 8 fractional bits
    # Range: -128.0 to 127.99609375
    scaled = int(f * 256)  # 2^8 = 256
    # Clamp to 16-bit signed range
    max_val = 32767
    min_val = -32768
    if scaled > max_val:
        scaled = max_val
    elif scaled < min_val:
        scaled = min_val
    return scaled

def q8_8_to_float(v):
    """Convert Q8.8 to float"""
    # Sign-extend from 16-bit if needed
    if v >= 32768:
        v = v - 65536
    return v / 256.0

def calculate_min_diff_pair(values):
    """Calculate expected pair in Python"""
    valid = [q8_8_to_float(v) for v in values]
    min_diff = float('inf')
    best_pair = (0, 0)
    
    for i in range(len(valid)):
        for j in range(i+1, len(valid)):
            diff = abs(valid[i] - valid[j])
            if diff < min_diff:
                min_diff = diff
                a, b = sorted([valid[i], valid[j]])
                best_pair = (float_to_q8_8(a), float_to_q8_8(b))
            elif diff == min_diff:
                # Return first found (as per spec)
                pass
    
    return best_pair

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_find_closest_elements(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    if has_signal(dut, 'clk'):
        for _ in range(2):
            await RisingEdge(dut.clk)
    else:
        await Timer(20, units='ns')
    
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ([1.0, 2.0, 3.0, 4.0, 5.0, 2.2], (2.0, 2.2)),
        ([1.0, 2.0, 3.9, 4.0, 5.0, 2.2], (3.9, 4.0)),
        ([1.0, 2.0, 5.9, 4.0, 5.0], (5.0, 5.9)),
        ([1.0, 2.0, 3.0, 4.0, 5.0, 2.0], (2.0, 2.0)),
        ([1.1, 2.2, 3.1, 4.1, 5.1], (2.2, 3.1)),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (floats, expected_tuple) in enumerate(test_cases):
        cocotb.log.info(f"Test case {idx+1}: {floats}")
        
        try:
            # Convert to Q8.8 and pad to 16 elements
            q8_values = [float_to_q8_8(f) for f in floats]
            while len(q8_values) < ARRAY_SIZE:
                q8_values.append(0)
            
            # Create valid mask (only first len(floats) are valid)
            mask = (1 << len(floats)) - 1
            
            # Write to DUT
            if has_signal(dut, 'data'):
                for i in range(ARRAY_SIZE):
                    dut.data[i].value = clamp_to_width(q8_values[i], DATA_WIDTH)
            else:
                # Handle individual ports
                for i in range(ARRAY_SIZE):
                    port_name = f'data_{i}'
                    if has_signal(dut, port_name):
                        getattr(dut, port_name).value = clamp_to_width(q8_values[i], DATA_WIDTH)
            
            if has_signal(dut, 'valid_mask'):
                dut.valid_mask.value = mask
            
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                if has_signal(dut, 'clk'):
                    await RisingEdge(dut.clk)
                else:
                    await Timer(CLK_NS, units='ns')
                dut.start.value = 0
            
            # Wait for done
            if has_signal(dut, 'done'):
                await wait_for_done(dut)
            else:
                await Timer(MAX_CYCLES * CLK_NS, units='ns')
            
            # Read results
            if has_signal(dut, 'result_valid'):
                result_valid = int(dut.result_valid.value)
            else:
                result_valid = 1
            
            if result_valid == 0:
                raise TestFailure(f"Result invalid for test {idx+1}")
            
            if not has_signal(dut, 'result_a') or not has_signal(dut, 'result_b'):
                raise TestFailure("Result signals not found")
            
            result_a_val = int(dut.result_a.value)
            result_b_val = int(dut.result_b.value)
            
            # Convert to signed
            result_a_signed = to_signed(result_a_val, DATA_WIDTH)
            result_b_signed = to_signed(result_b_val, DATA_WIDTH)
            
            # Convert back to float for comparison
            result_a_float = q8_8_to_float(result_a_signed)
            result_b_float = q8_8_to_float(result_b_signed)
            
            # Compare with expected
            exp_a = float_to_q8_8(expected_tuple[0])
            exp_b = float_to_q8_8(expected_tuple[1])
            exp_a_signed = to_signed(exp_a, DATA_WIDTH)
            exp_b_signed = to_signed(exp_b, DATA_WIDTH)
            
            exp_a_float = q8_8_to_float(exp_a_signed)
            exp_b_float = q8_8_to_float(exp_b_signed)
            
            # Allow small rounding error in fixed-point
            tolerance = 0.01
            if abs(result_a_float - exp_a_float) > tolerance or abs(result_b_float - exp_b_float) > tolerance:
                raise TestFailure(f"Expected ({exp_a_float}, {exp_b_float}), got ({result_a_float}, {result_b_float})")
            
            # Ensure order is correct (smaller first)
            if result_a_float > result_b_float:
                raise TestFailure(f"Result not sorted: ({result_a_float}, {result_b_float})")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {idx+1}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")

async def wait_for_done(dut, max_cycles=120):
    """Wait for done signal with timeout"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")
