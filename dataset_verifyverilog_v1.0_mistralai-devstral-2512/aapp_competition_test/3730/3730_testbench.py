import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Testbench constants
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 300

async def write_array(dut, name, vals, width):
    """Write array values element by element"""
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

async def reset_dut(dut, cycles=2):
    """Reset the DUT"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python reference implementation
def solve_reference(arr, n):
    """Python reference for the problem"""
    if n == 1:
        return 1
    if n == 2:
        return 2
    
    left = [1] * n
    right = [1] * n
    
    # Compute left lengths
    for i in range(1, n):
        if arr[i] > arr[i-1]:
            left[i] = left[i-1] + 1
    
    # Compute right lengths
    for i in range(n-2, -1, -1):
        if arr[i] < arr[i+1]:
            right[i] = right[i+1] + 1
    
    ans = 2  # Minimum answer for n>=2
    
    # Check single segments
    ans = max(ans, max(left), max(right))
    
    # Check merging two segments
    for i in range(1, n-1):
        if arr[i-1] + 1 < arr[i+1]:
            length = left[i-1] + right[i+1] + 1
            if length > ans:
                ans = length
        else:
            length = max(left[i-1], right[i+1]) + 1
            if length > ans:
                ans = length
    
    # Check endpoints
    if n > 2:
        ans = max(ans, left[n-2] + 1, right[1] + 1)
    
    return min(ans, n)  # Cap at n

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_longest_increasing_subsegment(dut):
    """Test the longest increasing subsegment module"""
    # Setup clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic
        await Timer(100, units='ns')
    
    # Test cases: (arr, n, expected_result, description)
    test_cases = [
        ([7, 2, 3, 1, 5, 6], 6, 5, "Original example"),
        ([1, 2, 3, 4, 5], 5, 5, "Already strictly increasing"),
        ([5, 4, 3, 2, 1], 5, 2, "Strictly decreasing (change one)"),
        ([1, 2, 2, 3, 4], 5, 5, "Single duplicate in middle"),
        ([1, 1, 1, 1, 1], 5, 2, "All equal (change one)"),
        ([1], 1, 1, "Single element"),
        ([1, 2], 2, 2, "Two elements"),
        ([1, 3, 2, 4, 5], 5, 5, "Swap needed"),
        ([1, 2, 1, 2, 4, 5], 6, 6, "Complex case"),
        ([42], 1, 1, "Single large element"),
        ([1000000000, 1000000000], 2, 2, "Two equal large numbers"),
        ([1, 2, 3, 4, 1], 5, 5, "Drop at end"),
        ([1, 2, 3, 4, 5, 5, 6, 7, 8, 9], 10, 6, "Multiple issues"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr, n, expected, desc) in enumerate(test_cases):
        # Skip if n > ARRAY_SIZE
        if n > ARRAY_SIZE:
            cocotb.log.warning(f"Skipping test {i+1}: n={n} > ARRAY_SIZE={ARRAY_SIZE}")
            continue
        
        cocotb.log.info(f"Test {i+1}/{len(test_cases)}: {desc} (n={n})")
        cocotb.log.info(f"  Input: {arr[:n]}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Write inputs
            if is_seq:
                await write_array(dut, 'arr', arr[:n], DATA_WIDTH)
                dut.n.value = n
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational logic
                await write_array(dut, 'arr', arr[:n], DATA_WIDTH)
                dut.n.value = n
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            cocotb.log.info(f"  Got: {result}")
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Additional random tests
    cocotb.log.info("Running random tests...")
    for test_num in range(10):
        n = random.randint(1, 10)
        arr = [random.randint(1, 100) for _ in range(n)]
        expected = solve_reference(arr, n)
        
        cocotb.log.info(f"Random test {test_num+1}: n={n}, arr={arr}")
        
        try:
            if is_seq:
                await write_array(dut, 'arr', arr, DATA_WIDTH)
                dut.n.value = n
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await write_array(dut, 'arr', arr, DATA_WIDTH)
                dut.n.value = n
                await Timer(100, units='ns')
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Random test {test_num+1} FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All tests passed! ({passed}/{passed + failed})")
