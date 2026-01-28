import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Configuration
DATA_WIDTH = 16
ARRAY_SIZE = 8
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
    if value < 0:
        # Handle signed values - not used here
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# Compute expected result for a given array (list of ints)
def compute_expected(arr):
    n = len(arr)
    # Count ones
    count_ones = sum(1 for x in arr if x == 1)
    if count_ones > 0:
        return n - count_ones
    # Overall gcd
    g = arr[0]
    for x in arr[1:]:
        g = math.gcd(g, x)
    if g != 1:
        return -1
    # Find shortest subarray with gcd 1
    min_len = n + 1
    for i in range(n):
        g = arr[i]
        for j in range(i, n):
            g = math.gcd(g, arr[j])
            if g == 1:
                min_len = min(min_len, j - i + 1)
                break
    if min_len == n + 1:
        return -1
    return (min_len - 1) + (n - 1)

# Pack array values into a single integer
def pack_array(values, element_bits=DATA_WIDTH, N=ARRAY_SIZE):
    packed = 0
    for i in range(N):
        val = values[i] if i < len(values) else 0
        packed |= clamp_to_width(val, element_bits) << (i * element_bits)
    return packed

# Reset DUT
async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Wait for done signal
async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

# Main test
@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_min_ops_to_one(dut):
    '''Test the min_ops_to_one module.'''
    
    # Detect interface
    if not has_signal(dut, 'clk'):
        raise TestFailure('DUT must have clk signal')
    if not has_signal(dut, 'rst_n'):
        raise TestFailure('DUT must have rst_n signal')
    if not has_signal(dut, 'start'):
        raise TestFailure('DUT must have start signal')
    if not has_signal(dut, 'arr'):
        raise TestFailure('DUT must have arr signal (packed array)')
    if not has_signal(dut, 'result'):
        raise TestFailure('DUT must have result signal')
    if not has_signal(dut, 'done'):
        raise TestFailure('DUT must have done signal')
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset DUT
    await reset_dut(dut)
    
    # Define test cases: (n, input_list, description)
    # Only include cases where n <= ARRAY_SIZE
    test_cases = [
        (5, [2, 2, 3, 4, 6], 'Example 1'),
        (4, [2, 4, 6, 8], 'Example 2 (no 1)'),
        (3, [2, 6, 9], 'Example 3'),
        (1, [3], 'Single element non-1'),
        (2, [1, 1], 'All ones'),
        (2, [1000000000, 1000000000], 'Large numbers'),
        (3, [42, 15, 35], 'GCD 1 subarray length 2'),
        (3, [6, 10, 15], 'GCD 1 subarray length 2'),
        (4, [2, 1, 1, 1], 'One 1'),
        (5, [2, 1, 1, 1, 2], 'One 1 with extras'),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, input_list, description) in enumerate(test_cases):
        cocotb.log.info(f'Test {i+1}: {description}')
        
        # Clamp input values to DATA_WIDTH bits
        clamped_input = [clamp_to_width(x, DATA_WIDTH) for x in input_list]
        
        # Pack array
        packed_value = pack_array(clamped_input, DATA_WIDTH, ARRAY_SIZE)
        dut.arr.value = packed_value
        
        # Compute expected result based on clamped inputs
        expected = compute_expected(clamped_input)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure('Result is undefined')
        
        actual = int(dut.result.value)
        
        # Convert expected -1 to 0xFFFF
        if expected == -1:
            expected_val = 0xFFFF
        else:
            expected_val = expected
        
        if actual != expected_val:
            cocotb.log.error(f'  FAIL: expected {expected_val}, got {actual}')
            failed += 1
        else:
            cocotb.log.info(f'  PASS: result = {actual}')
            passed += 1
    
    cocotb.log.info('=' * 50)
    cocotb.log.info(f'Results: {passed}/{passed + failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')