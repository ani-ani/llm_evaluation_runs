import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
K = 5
N = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# Mandatory helper functions
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

# Helper to compute Hamming distance
def hamming_dist(a, b, k):
    xor_val = a ^ b
    dist = 0
    for i in range(k):
        dist += (xor_val >> i) & 1
    return dist

# Compute optimal minimum distance
def compute_optimal_min_dist(strings, k):
    best_min = -1
    for candidate in range(1 << k):
        min_dist = k
        for s in strings:
            dist = hamming_dist(candidate, s, k)
            if dist < min_dist:
                min_dist = dist
        if min_dist > best_min:
            best_min = min_dist
    return best_min

# Set input strings
def set_strings(dut, strings, k):
    for i, s in enumerate(strings):
        if i < N:
            if has_signal(dut, f'str{i}'):
                setattr(dut, f'str{i}').value = s
            else:
                raise TestFailure(f'Signal str{i} not found')
    # Set remaining to 0
    for i in range(len(strings), N):
        if has_signal(dut, f'str{i}'):
            setattr(dut, f'str{i}').value = 0
        else:
            raise TestFailure(f'Signal str{i} not found')

# Reset DUT
async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(N):
        if has_signal(dut, f'str{i}'):
            getattr(dut, f'str{i}').value = 0
    if has_signal(dut, 'n'):
        dut.n.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Wait for done
async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

# Start computation
async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# Main test
@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_find_character(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    strings1 = [int('01001', 2), int('11100', 2), int('10111', 2)]
    n1 = 3
    strings2 = [int('00000', 2)]  # pad to 5 bits
    n2 = 1
    
    test_cases = [
        (strings1, n1, 'Example 1: 3 strings, k=5'),
        (strings2, n2, 'Example 2: 1 string, k=5'),
    ]
    
    for i, (strings, n, desc) in enumerate(test_cases):
        dut._log.info(f'Test {i+1}: {desc}')
        
        # Set strings
        set_strings(dut, strings, K)
        
        # Set n
        if has_signal(dut, 'n'):
            dut.n.value = n
        else:
            raise TestFailure("Signal 'n' not found")
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure('Result is undefined')
        
        result = int(dut.result.value)
        
        # Compute minimum distance for result
        min_dist = K
        for s in strings:
            dist = hamming_dist(result, s, K)
            if dist < min_dist:
                min_dist = dist
        
        # Compute optimal minimum distance
        optimal_min_dist = compute_optimal_min_dist(strings, K)
        
        if min_dist != optimal_min_dist:
            raise TestFailure(f'Result does not achieve optimal minimum distance. Got {min_dist}, expected {optimal_min_dist}')
        
        dut._log.info(f'  PASS: result = {bin(result)[2:].zfill(K)}, min_dist = {min_dist}')

    dut._log.info('All tests passed!')