import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MOD = 1000000007
MAX_K = 8
CLK_PERIOD_NS = 10
TIMEOUT_CYCLES = 1000

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL HELPERS
# ============================================================================
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=TIMEOUT_CYCLES):
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
# PYTHON REFERENCE FUNCTION (for expected results)
# ============================================================================
def compute_expected(N, k):
    '''Compute expected result using Python (same formula as Verilog).'''
    MOD = 1000000007
    # Stirling numbers S(k,i) using DP
    dp = [0] * (k+1)
    dp[0] = 1
    for n in range(1, k+1):
        for i in range(n, 0, -1):
            dp[i] = (i * dp[i] + dp[i-1]) % MOD
        dp[0] = 0
    # Factorials
    fact = [1] * (k+1)
    for i in range(1, k+1):
        fact[i] = fact[i-1] * i % MOD
    # Inverses (using precomputed for small k)
    inv = [0] * (k+1)
    for i in range(1, k+1):
        inv[i] = pow(i, MOD-2, MOD)
    # Binomial coefficients
    comb = [1] * (k+1)
    for i in range(1, k+1):
        comb[i] = comb[i-1] * ((N - i + 1) % MOD) % MOD * inv[i] % MOD
    # Power of 2
    pow2_N = pow(2, N, MOD)
    inv2 = pow(2, MOD-2, MOD)
    # Sum
    result = 0
    pow2_N_i = pow2_N
    for i in range(k+1):
        term = dp[i] * fact[i] % MOD * comb[i] % MOD * pow2_N_i % MOD
        result = (result + term) % MOD
        pow2_N_i = pow2_N_i * inv2 % MOD
    return result

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_subset_cost_sum(dut):
    '''Test the SubsetCostSum module.'''
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (N, k, description)
    test_cases = [
        (1, 1, 'Small: N=1,k=1'),
        (3, 2, 'Small: N=3,k=2'),
        (5, 3, 'Small: N=5,k=3'),
        (12, 4, 'Small: N=12,k=4'),
        (20, 5, 'Small: N=20,k=5'),
        (1, 8, 'Max k: N=1,k=8'),
        (100, 8, 'Medium N, max k: N=100,k=8'),
        (1000000000, 8, 'Large N, max k: N=1e9,k=8'),
    ]
    
    passed = 0
    failed = 0
    
    for N, k, desc in test_cases:
        # Skip if k > MAX_K (should not happen)
        if k > MAX_K:
            dut._log.warning(f'Skipping {desc}: k={k} > MAX_K={MAX_K}')
            continue
        
        dut._log.info(f'Test: {desc}')
        
        # Set inputs
        dut.N.value = N
        dut.k.value = k
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            dut._log.error(f'  FAIL: {e}')
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            dut._log.error('  FAIL: result is undefined (X/Z)')
            failed += 1
            continue
        
        result = int(dut.result.value)
        expected = compute_expected(N, k)
        
        if result != expected:
            dut._log.error(f'  FAIL: expected {expected}, got {result}')
            failed += 1
        else:
            dut._log.info(f'  PASS: result = {result}')
            passed += 1
    
    # Summary
    dut._log.info(f'{'='*60}')
    dut._log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')
