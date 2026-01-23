import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MOD = 1000000007
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS (as per template)
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# COMPUTE EXPECTED ANSWER (Python)
# ============================================================================

def compute_answer(N, K):
    """Compute the answer using the divisor enumeration method."""
    # Find all divisors of N
    divisors = []
    i = 1
    while i * i <= N:
        if N % i == 0:
            divisors.append(i)
            if i * i != N:
                divisors.append(N // i)
        i += 1
    divisors.sort()
    
    # v[d] = number of primitive palindromes of period d
    v = {}
    ans = 0
    for d in divisors:
        # base = K^{ceil(d/2)}
        exp = (d + 1) // 2
        base = pow(K, exp, MOD)
        # subtract v of divisors that divide d and are smaller
        for d2 in divisors:
            if d2 >= d:
                break
            if d % d2 == 0:
                base = (base - v[d2]) % MOD
        v[d] = base % MOD
        # contribution
        if d % 2 == 0:
            contrib = (v[d] * (d // 2)) % MOD
        else:
            contrib = (v[d] * d) % MOD
        ans = (ans + contrib) % MOD
    return ans

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_palindrome_sequence_counter(dut):
    """Test the palindrome sequence counter module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (N, K, expected)
    test_cases = [
        (4, 2, 6),
        (1, 10, 10),
        (6, 3, 75),
        (1, 1, 1),
        (2, 2, 2),
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, K, expected) in enumerate(test_cases):
        cocotb.log.info(f'Test {i+1}: N={N}, K={K}, expected={expected}')
        
        # Write inputs
        dut.N.value = N
        dut.K.value = K
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            cocotb.log.error(f'  FAIL: {e}')
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error('  FAIL: result is undefined')
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f'  FAIL: expected {expected}, got {result}')
            failed += 1
        else:
            cocotb.log.info(f'  PASS: result = {result}')
            passed += 1
    
    # Summary
    cocotb.log.info('=' * 50)
    cocotb.log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')