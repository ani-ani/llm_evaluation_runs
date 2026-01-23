import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_N = 8
MAX_M = 8
MAX_B = 8
DATA_WIDTH = 9   # a_i up to 500 fits in 9 bits
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10

# ============================================================================
# HELPER FUNCTIONS (from specification)
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

async def wait_for_done(dut, max_cycles=10000):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# EXPECTED RESULT CALCULATION (Python DP)
# ============================================================================

def compute_expected(n, m, b, mod, a):
    """Compute the answer using the same DP algorithm."""
    # dp[lines][bugs]
    dp = [[0] * (b + 1) for _ in range(m + 1)]
    dp[0][0] = 1
    for ai in a:
        for lines in range(1, m + 1):
            for bugs in range(ai, b + 1):
                dp[lines][bugs] = (dp[lines][bugs] + dp[lines - 1][bugs - ai]) % mod
    total = 0
    for bugs in range(b + 1):
        total = (total + dp[m][bugs]) % mod
    return total

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bug_free_plans(dut):
    """Test the bug_free_plans module with scaled-down test cases."""
    
    # Detect if module has required signals
    if not has_signal(dut, 'clk'):
        raise TestFailure("DUT missing 'clk' signal")
    if not has_signal(dut, 'rst_n'):
        raise TestFailure("DUT missing 'rst_n' signal")
    if not has_signal(dut, 'start'):
        raise TestFailure("DUT missing 'start' signal")
    if not has_signal(dut, 'done'):
        raise TestFailure("DUT missing 'done' signal")
    if not has_signal(dut, 'result'):
        raise TestFailure("DUT missing 'result' signal")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, m, b, mod, a_list, expected_description)
    # All cases fit within MAX_M=8, MAX_B=8, MAX_N=8
    test_cases = [
        (3, 3, 3, 100, [1, 1, 1], 10),
        (3, 6, 5, 1000000007, [1, 2, 3], 0),
        (3, 5, 6, 11, [1, 2, 1], 0),
        (2, 3, 3, 1000, [1, 2], 1),
        (1, 1, 0, 1000, [0], 1),
        (1, 4, 25, 1000, [6], 1),
        (1, 5, 1, 10, [1], 0),
        (1, 5, 5, 1000, [1], 1),
        (1, 5, 5, 1000, [500], 0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, m, b, mod, a_list, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: n={n}, m={m}, b={b}, mod={mod}, a={a_list}")
        
        try:
            # Set inputs
            dut.n.value = n
            dut.m.value = m
            dut.b.value = b
            dut.mod.value = mod
            
            # Set a_i ports (only first n are used)
            for idx in range(MAX_N):
                if idx < n:
                    getattr(dut, f'a_{idx}').value = a_list[idx]
                else:
                    getattr(dut, f'a_{idx}').value = 0
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Compare
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")