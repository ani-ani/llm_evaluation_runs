import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 8
DATA_WIDTH = 4
RESULT_WIDTH = 3
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

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
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

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
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# PYTHON REFERENCE IMPLEMENTATION
# ============================================================================

def compute_shuffle_number(perm):
    n = len(perm)
    # positions
    pos = [0]*n
    for i, val in enumerate(perm):
        pos[val-1] = i
    # inc
    inc = [0]*(n-1)
    for i in range(n-1):
        inc[i] = 1 if pos[i] < pos[i+1] else 0
    # DP
    f = [[0]*n for _ in range(n)]
    for i in range(n):
        f[i][i] = 0
    for length in range(2, n+1):
        for l in range(0, n-length+1):
            r = l + length - 1
            best = 100
            for m in range(l, r):
                cost = 1 + max(f[l][m], f[m+1][r])
                if cost < best:
                    best = cost
            f[l][r] = best
    return f[0][n-1]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_shuffle_number(dut):
    '''Test the shuffle number module.'''
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        ([1,2,3,4,5,6,7,8], 'Identity'),
        ([8,7,6,5,4,3,2,1], 'Reverse'),
        ([2,1,4,3,6,5,8,7], 'Example 3'),
        ([1,2,3,4,5,6,8,7], 'Swap last two'),
        ([1,2,7,3,8,9,4,5], 'Truncated example 1'),
    ]
    
    passed = 0
    failed = 0
    
    for perm, description in test_cases:
        cocotb.log.info(f'Test: {description}')
        
        # Compute expected result
        expected = compute_shuffle_number(perm)
        cocotb.log.info(f'  Expected: {expected}')
        
        # Write permutation to DUT
        for i in range(N):
            val = perm[i]
            if val > (1<<DATA_WIDTH)-1:
                raise ValueError(f'Value {val} exceeds DATA_WIDTH')
            # Assign to perm_i
            if has_signal(dut, f'perm_{i}'):
                getattr(dut, f'perm_{i}').value = val
            else:
                # Fallback to indexed array if exists
                if has_signal(dut, 'perm'):
                    dut.perm[i].value = val
                else:
                    raise TestFailure(f'Cannot find port for perm_{i}')
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure('Result is undefined (X/Z)')
        
        actual = int(dut.result.value)
        
        if actual != expected:
            cocotb.log.error(f'  FAIL: expected {expected}, got {actual}')
            failed += 1
        else:
            cocotb.log.info(f'  PASS')
            passed += 1
    
    # Summary
    cocotb.log.info(f'{"="*50}')
    cocotb.log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')