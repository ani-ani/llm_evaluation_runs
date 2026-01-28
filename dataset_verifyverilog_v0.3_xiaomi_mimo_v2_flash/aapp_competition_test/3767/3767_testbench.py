import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_N = 16
DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000000  # Large for DP computation

# ============================================================================
# HELPER FUNCTIONS
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

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

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
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# PYTHON REFERENCE IMPLEMENTATION
# ============================================================================

def solve_python(n, a, b):
    """Python reference for verification."""
    # Scale down: use same algorithm as Verilog
    total_soda = sum(a)
    
    # Sort bottles by volume descending
    bottles = sorted(zip(b, a), reverse=True)
    
    # DP table: dp[k][v] = max sum of a_i for k bottles with total volume v
    # We cap v at total_soda
    dp = [[-1] * (total_soda + 1) for _ in range(n + 1)]
    dp[0][0] = 0
    
    for bottle_b, bottle_a in bottles:
        for k in range(n, 0, -1):
            for v in range(total_soda, -1, -1):
                if dp[k-1][v] != -1:
                    new_v = min(total_soda, v + bottle_b)
                    new_sum = dp[k-1][v] + bottle_a
                    if new_sum > dp[k][new_v]:
                        dp[k][new_v] = new_sum
    
    # Find minimal k
    for k in range(1, n+1):
        if dp[k][total_soda] != -1:
            return k, total_soda - dp[k][total_soda]
    
    return n, 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_soda_bottles(dut):
    """Main test for soda_bottles module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        ([3, 3, 4, 3], [4, 7, 6, 5], 2, 6, "Example 1"),
        ([1, 1], [100, 100], 1, 1, "Example 2"),
        ([10, 30, 5, 6, 24], [10, 41, 7, 8, 24], 3, 11, "Example 3"),
        ([1], [100], 1, 0, "Single bottle"),
        ([1, 1], [1, 1], 2, 0, "Two full bottles"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a_vals, b_vals, expected_k, expected_t, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        # Scale down: limit to MAX_N
        n = len(a_vals)
        if n > MAX_N:
            cocotb.log.warning(f"Skipping test {i+1}: n={n} exceeds MAX_N={MAX_N}")
            continue
        
        # Pad arrays to MAX_N
        a_padded = a_vals + [0] * (MAX_N - n)
        b_padded = b_vals + [0] * (MAX_N - n)
        
        # Set inputs
        dut.n.value = n
        for idx in range(MAX_N):
            dut.a[idx].value = a_padded[idx]
            dut.b[idx].value = b_padded[idx]
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read results
        if not is_value_defined(dut.k.value) or not is_value_defined(dut.t.value):
            cocotb.log.error(f"Test {i+1}: Output undefined")
            failed += 1
            continue
        
        result_k = int(dut.k.value)
        result_t = int(dut.t.value)
        
        # Verify
        if result_k == expected_k and result_t == expected_t:
            cocotb.log.info(f"  PASS: k={result_k}, t={result_t}")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: Expected k={expected_k}, t={expected_t}, got k={result_k}, t={result_t}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")