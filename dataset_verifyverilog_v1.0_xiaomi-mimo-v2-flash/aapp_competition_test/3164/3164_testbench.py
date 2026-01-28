import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 16
ARRAY_SIZE = 256
CLK_NS = 10
MAX_CYCLES = 20000
SCALE_FACTOR = 1000  # Divide original values by 1000

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def scale_value(val):
    """Scale down by 1000 to fit in 16-bit range"""
    return clamp_to_width(val // SCALE_FACTOR, DATA_WIDTH)

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, vals, width):
    """Write array values individually to avoid HDL assignment issues"""
    for i, v in enumerate(vals):
        getattr(dut, f"{name}_{i}").value = clamp_to_width(v, width)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_consecutive_twice(dut):
    """Test cases for consecutive sub-array with exactly twice elements"""
    
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational mode - test directly
        await Timer(100, units='ns')
    
    # Test cases (scaled)
    test_cases = [
        # Original: [1,2,3,3,4,2] -> Scaled: [1,2,3,3,4,2] -> Expected: 2 (subarray [3,3] or [2]?
        # Actually [3,3] has element 3 appearing exactly twice? No, it appears twice total in subarray.
        # Wait: "each element in the sub-array appears exactly twice"
        # [3,3]: element 3 appears twice -> valid, length 2
        ([1,2,3,3,4,2], 2, "Sample 1: [1,2,3,3,4,2]"),
        # Original: [1,2,1,3,1,3,1,2] -> Scaled: [1,2,1,3,1,3,1,2]
        # Longest valid: [1,3,1,3] (length 4) or [2,1,3,1]?
        # [1,3,1,3]: 1 appears twice, 3 appears twice -> valid, length 4
        ([1,2,1,3,1,3,1,2], 4, "Sample 2: [1,2,1,3,1,3,1,2]"),
        # Original: [1,10,100,1000,100,10,1] -> Scaled: [1,10,100,1,100,10,1]
        # Longest valid: None (no element appears exactly twice in a consecutive subarray)
        ([1,10,100,1,100,10,1], 0, "Sample 3: [1,10,100,1,100,10,1]"),
        # Additional test: [2,2,3,3,4,4] -> Should find 2 (any pair)
        ([2,2,3,3,4,4], 2, "Pairs: [2,2,3,3,4,4]"),
        # Additional test: [1,1,2,2,2,2] -> Longest: [2,2,2,2] (2 appears 4 times? No)
        # Each element must appear exactly twice: [2,2] works, but [2,2,2,2] has 2 appearing 4 times -> invalid
        # So max is 2
        ([1,1,2,2,2,2], 2, "Quad: [1,1,2,2,2,2]"),
        # Additional test: [5,5,6,6,7,7,8,8] -> Should find 2
        ([5,5,6,6,7,7,8,8], 2, "Multiple pairs: [5,5,6,6,7,7,8,8]"),
        # Additional test: [10,20,10,20] -> Both appear exactly twice, length 4
        ([10,20,10,20], 4, "Alternating: [10,20,10,20]"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_vals, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Scale input values
        scaled_vals = [scale_value(v) for v in input_vals]
        actual_len = len(input_vals)
        
        try:
            if is_seq:
                # Write array to dut
                for idx, val in enumerate(scaled_vals):
                    dut.arr[idx].value = clamp_to_width(val, DATA_WIDTH)
                
                # Write length
                dut.len.value = actual_len
                
                # Start processing
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, MAX_CYCLES)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                
                cocotb.log.info(f"PASS: {desc} - Result: {result}")
                passed += 1
                
            else:
                # Combinational - set inputs and read output
                for idx, val in enumerate(scaled_vals):
                    dut.arr[idx].value = clamp_to_width(val, DATA_WIDTH)
                dut.len.value = actual_len
                
                await Timer(100, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                
                cocotb.log.info(f"PASS: {desc} - Result: {result}")
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed} tests")
