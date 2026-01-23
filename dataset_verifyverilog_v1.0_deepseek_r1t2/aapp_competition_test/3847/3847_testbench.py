import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def write_array(dut, array_name, values, element_width):
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    results = []
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# Helper to compute expected result
def compute_expected(n, m, a, b, x):
    # Compute min segment sums for all lengths
    min_row = [float('inf')] * (n+1)
    min_col = [float('inf')] * (m+1)
    
    for L in range(1, n+1):
        for start in range(n - L + 1):
            s = sum(a[start:start+L])
            if s < min_row[L]:
                min_row[L] = s
    
    for L in range(1, m+1):
        for start in range(m - L + 1):
            s = sum(b[start:start+L])
            if s < min_col[L]:
                min_col[L] = s
    
    max_area = 0
    for L1 in range(1, n+1):
        for L2 in range(1, m+1):
            if min_row[L1] * min_col[L2] <= x:
                area = L1 * L2
                if area > max_area:
                    max_area = area
    return max_area

# Main test
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_max_area(dut):
    """Test find_max_area module with various cases"""
    
    # Detect interface
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    # Test cases: (n, m, a_list, b_list, x, expected_area)
    test_cases = [
        (3, 3, [1,2,3], [1,2,3], 9, 4),
        (5, 1, [5,4,2,4,5], [2], 5, 1),
        (1, 1, [1], [1], 1, 1),
        (2, 2, [255,255], [255,255], 1000000, 4),
        (8, 8, [1]*8, [1]*8, 10, 64),  # Full area
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, m, a_list, b_list, x, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, m={m}, x={x}")
        
        # Pad arrays to size 8
        a_padded = a_list + [0] * (8 - len(a_list))
        b_padded = b_list + [0] * (8 - len(b_list))
        
        # Write inputs
        dut.n.value = n
        dut.m.value = m
        dut.x.value = x
        
        # Write arrays element by element
        for idx in range(8):
            dut.a[idx].value = a_padded[idx]
            dut.b[idx].value = b_padded[idx]
        
        if is_sequential:
            # Start computation and wait for done
            await start_computation(dut)
            await wait_for_done(dut)
            # Read result
            if is_value_defined(dut.result.value):
                result = int(dut.result.value)
            else:
                raise TestFailure(f"Result is undefined (X/Z)")
        else:
            # Combinational - wait for propagation
            await Timer(100, units='ns')
            result = int(dut.result.value)
        
        # Verify
        if result != expected:
            cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
