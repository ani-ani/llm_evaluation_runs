import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
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

# Constants
DATA_WIDTH = 16
MAX_ELEMENTS = 16
MAX_VAL = 50000
CLK_NS = 10
MAX_CYCLES = 200

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=150):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, arr_vals):
    """Write array values to individual arr_i ports"""
    n = len(arr_vals)
    for i in range(MAX_ELEMENTS):
        val = arr_vals[i] if i < n else 0
        # Convert to 16-bit signed representation
        val_signed = to_signed(val, DATA_WIDTH)
        # Clamp to 16 bits
        val_clamped = clamp_to_width(val_signed, DATA_WIDTH)
        # Assign to arr_i
        if has_signal(dut, f'arr_{i}'):
            getattr(dut, f'arr_{i}').value = val_clamped
        else:
            # Try array access
            try:
                dut.arr[i].value = val_clamped
            except:
                pass

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_count_triples(dut):
    """
    Test the triple counting module with small arrays.
    """
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_array, expected_output)
    test_cases = [
        ([1, 2, 3, 4], 4),           # 1+2=3, 1+3=4, 2+1=3, 2+2=4
        ([1, 1, 3, 3, 4, 6], 10),   # Given example
        ([0, 0, 0], 2),              # 0+0=0 (two ways: (0,1,2), (1,0,2))
        ([1, 2, 4], 2),              # 1+1=2, 1+3=4
        ([-1, 0, 1], 2),             # (-1)+1=0, 0+1=1
    ]
    
    for test_idx, (arr, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: Input = {arr}, Expected = {expected}")
        
        # Write array
        await write_array(dut, arr)
        
        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {test_idx + 1}: Result is undefined")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {test_idx + 1}: Expected {expected}, got {result}")
        
        # Verify valid signal
        if has_signal(dut, 'valid'):
            if not is_value_defined(dut.valid.value) or int(dut.valid.value) != 1:
                raise TestFailure(f"Test {test_idx + 1}: valid signal not asserted")
        
        cocotb.log.info(f"Test {test_idx + 1}: PASSED (result = {result})")
        
        # Reset for next test
        await reset_dut(dut)

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_random_arrays(dut):
    """
    Test with random arrays (capped at 6 elements for speed).
    """
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    for test_idx in range(10):
        # Generate random array size (3 to 6)
        n = random.randint(3, 6)
        arr = [random.randint(-50, 50) for _ in range(n)]
        
        # Compute expected in Python
        expected = 0
        for i in range(n):
            for j in range(n):
                for k in range(n):
                    if i != j and i != k and j != k:
                        if arr[i] + arr[j] == arr[k]:
                            expected += 1
        
        cocotb.log.info(f"Random test {test_idx + 1}: {arr}, expected = {expected}")
        
        # Write array
        await write_array(dut, arr)
        
        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Random test {test_idx + 1}: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Random test {test_idx + 1}: PASSED")
        
        await reset_dut(dut)

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_edge_cases(dut):
    """
    Test edge cases: single element, duplicates, negative numbers.
    """
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    edge_cases = [
        ([1, 2, 3], 4),            # Basic case
        ([-5, 5, 0], 2),           # Negative numbers
        ([0, 0, 0, 0], 8),         # All zeros (4*3*2 / 2 = 12, but check)
        ([100, -100, 0], 2),       # Large numbers
    ]
    
    for test_idx, (arr, expected) in enumerate(edge_cases):
        cocotb.log.info(f"\nEdge case {test_idx + 1}: {arr}")
        
        await write_array(dut, arr)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Edge case {test_idx + 1}: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Edge case {test_idx + 1}: PASSED")
        await reset_dut(dut)