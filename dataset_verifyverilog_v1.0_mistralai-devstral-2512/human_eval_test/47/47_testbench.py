import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 8
MAX_LEN = 16
CLK_NS = 10
MAX_CYCLES = 1000
FRAC_BITS = 8  # Q8.8 format

# Helpers

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def float_to_fixed(f, frac=FRAC_BITS):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=FRAC_BITS):
    return v / (1 << frac)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def expected_median(arr):
    """Compute expected median as Q8.8 fixed point"""
    sorted_arr = sorted(arr)
    n = len(sorted_arr)
    if n % 2 == 1:
        # Odd length: middle element
        median = sorted_arr[n // 2]
        return float_to_fixed(median)
    else:
        # Even length: average of two middle elements
        mid1 = sorted_arr[n // 2 - 1]
        mid2 = sorted_arr[n // 2]
        avg = (mid1 + mid2) / 2.0
        return float_to_fixed(avg)

def verify_fixed_point(result, expected):
    """Verify Q8.8 fixed point result with tolerance"""
    return abs(result - expected) <= 1  # Allow 1/256 unit error

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_median(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        ([3, 1, 2, 4, 5], 3),
        ([-10, 4, 6, 1000, 10, 20], 8.0),
        ([5], 5),
        ([6, 5], 5.5),
        ([8, 1, 3, 9, 9, 2, 7], 7)
    ]
    
    passed = failed = 0
    
    for i, (arr, exp_float) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input {arr}, Expected {exp_float}")
        
        try:
            # Validate length
            n = len(arr)
            if n > MAX_LEN:
                raise TestFailure(f"Array length {n} exceeds max {MAX_LEN}")
            
            # Start calculation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Write array elements with valid flags
            for j, val in enumerate(arr):
                # Clamp and convert to signed 8-bit
                val_signed = to_signed(val, DATA_WIDTH) if val < 0 else val
                if val_signed < 0 or val_signed > 255:
                    raise TestFailure(f"Value {val} out of 8-bit range")
                
                dut.data_in.value = val_signed
                dut.data_in_valid.value = 1
                await RisingEdge(dut.clk)
                dut.data_in_valid.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result_val = int(dut.result.value)
            # Convert from Q8.8 to float for comparison
            result_float = fixed_to_float(result_val)
            
            # Compare with expected
            exp_val = expected_median(arr)
            exp_float_calc = fixed_to_float(exp_val)
            
            if not verify_fixed_point(result_val, exp_val):
                raise TestFailure(f"Expected Q8.8 {exp_val:#06x} ({exp_float_calc}), got Q8.8 {result_val:#06x} ({result_float})")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {i+1} - {e}")
            failed += 1
    
    # Additional random tests
    for i in range(5):
        n = random.randint(1, MAX_LEN)
        arr = [random.randint(-128, 127) for _ in range(n)]
        
        cocotb.log.info(f"Random Test {i+1}: Length {n}")
        try:
            # Reset for clean start
            await reset_dut(dut)
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Write array
            for j, val in enumerate(arr):
                val_signed = to_signed(val, DATA_WIDTH) if val < 0 else val
                dut.data_in.value = val_signed
                dut.data_in_valid.value = 1
                await RisingEdge(dut.clk)
                dut.data_in_valid.value = 0
            
            # Wait
            await wait_for_done(dut)
            
            # Verify
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result_val = int(dut.result.value)
            result_float = fixed_to_float(result_val)
            
            exp_val = expected_median(arr)
            exp_float_calc = fixed_to_float(exp_val)
            
            if not verify_fixed_point(result_val, exp_val):
                raise TestFailure(f"Random test failed: Expected {exp_float_calc}, got {result_float}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Random test {i+1} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All tests passed: {passed} passed, {failed} failed")