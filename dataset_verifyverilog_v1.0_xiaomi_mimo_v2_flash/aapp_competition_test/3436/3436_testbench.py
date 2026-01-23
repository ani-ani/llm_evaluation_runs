import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4   # x and y are 4-bit
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    '''Check if a cocotb value is defined (not X or Z).'''
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    '''Safely convert cocotb value to int, returning default if X/Z.'''
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    '''Check if DUT has a signal with given name.'''
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    '''Reset the DUT (active-low reset).'''
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0

    for _ in range(cycles):
        await RisingEdge(dut.clk)

    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    '''Wait for done signal with timeout.'''
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

async def start_computation(dut, x, y):
    '''Pulse start signal for one cycle and set x,y.'''
    # Set inputs
    dut.x.value = x
    dut.y.value = y
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# COMPUTE EXPECTED VALUE USING PYTHON
# ============================================================================

def compute_expected(x, y):
    '''Compute F_{x,y} modulo 1e9+7 using Python.'''
    MOD = 1000000007
    max_dim = max(x, y)
    dp = [[0]*(max_dim+1) for _ in range(max_dim+1)]
    dp[0][0] = 0
    if y >= 1:
        dp[0][1] = 1
    if x >= 1:
        dp[1][0] = 1
    for i in range(max_dim+1):
        for j in range(max_dim+1):
            if i == 0 and j == 0:
                continue
            if i == 0 and j == 1:
                continue
            if i == 1 and j == 0:
                continue
            if i == 0:
                dp[i][j] = (dp[i][j-1] + dp[i][j-2]) % MOD
            elif j == 0:
                dp[i][j] = (dp[i-1][j] + dp[i-2][j]) % MOD
            else:
                dp[i][j] = (dp[i-1][j] + dp[i][j-1]) % MOD
    return dp[x][y]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_compute_F(dut):
    '''Test the compute_F module.'''
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (x, y, expected)
    test_cases = [
        (1, 1, 2),
        (2, 2, 6),
        (1, 5, 13),
        (3, 4, 41),
        (4, 5, 155),
        (5, 5, 310),
        (6, 6, compute_expected(6,6)),
        (7, 7, compute_expected(7,7)),
        (8, 8, compute_expected(8,8)),
    ]
    
    passed = 0
    failed = 0
    
    for i, (x, y, expected) in enumerate(test_cases):
        cocotb.log.info(f'Test {i+1}: F({x},{y}) = {expected}')
        
        try:
            # Start computation
            await start_computation(dut, x, y)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f'Result is undefined (X/Z)')
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f'Expected {expected}, got {result}')
            
            cocotb.log.info(f'  PASS: result = {result}')
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f'  FAIL: {e}')
            failed += 1
    
    # Summary
    cocotb.log.info('='*50)
    cocotb.log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')