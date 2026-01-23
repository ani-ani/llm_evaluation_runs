import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N_WIDTH = 4        # n_in is 4 bits (0-8)
M_WIDTH = 4        # m_in is 4 bits (0-7)
RESULT_WIDTH = 16  # result is 16 bits
CLK_PERIOD_NS = 10
MAX_CYCLES = 500   # Enough for n=8 computation

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
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
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut, n_val, m_val):
    """Set inputs and pulse start signal."""
    dut.n_in.value = clamp_to_width(n_val, N_WIDTH)
    dut.m_in.value = clamp_to_width(m_val, M_WIDTH)
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# EULERIAN REFERENCE FUNCTION
# ============================================================================

def eulerian_num(n, m):
    """Reference Python implementation for validation."""
    if m >= n or n == 0:
        return 0
    if m == 0:
        return 1
    return ((n - m) * eulerian_num(n - 1, m - 1) + 
            (m + 1) * eulerian_num(n - 1, m))

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_eulerian_num(dut):
    """Test Eulerian number computation module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, m, expected)
    # Include edge cases and main test cases from problem
    test_cases = [
        # Edge cases
        (0, 0, 0, "n=0, m=0"),
        (1, 0, 1, "n=1, m=0"),
        (1, 1, 0, "n=1, m=1 (m>=n)"),
        (2, 0, 1, "n=2, m=0"),
        (2, 1, 1, "n=2, m=1"),
        (2, 2, 0, "n=2, m=2 (m>=n)"),
        # Main test cases from problem
        (3, 1, 4, "Test 1: eulerian_num(3, 1) == 4"),
        (4, 1, 11, "Test 2: eulerian_num(4, 1) == 11"),
        (5, 3, 26, "Test 3: eulerian_num(5, 3) == 26"),
        # Additional tests
        (3, 0, 1, "n=3, m=0"),
        (3, 2, 4, "n=3, m=2"),
        (4, 0, 1, "n=4, m=0"),
        (4, 2, 11, "n=4, m=2"),
        (5, 0, 1, "n=5, m=0"),
        (5, 1, 26, "n=5, m=1"),
        (5, 2, 66, "n=5, m=2"),
        (8, 4, 1764, "n=8, m=4 (largest value)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, m_val, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: n={n_val}, m={m_val}, Expected: {expected}")
        
        try:
            # Start computation
            await start_computation(dut, n_val, m_val)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_eulerian_edge_cases(dut):
    """Test edge cases and boundary conditions."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    edge_cases = [
        # m >= n cases (should return 0)
        (5, 5, 0, "m = n"),
        (5, 6, 0, "m > n"),
        (3, 7, 0, "m >> n"),
        # n = 0 cases
        (0, 0, 0, "n=0, m=0"),
        (0, 1, 0, "n=0, m=1"),
        # m = 0 cases (should be 1)
        (6, 0, 1, "n=6, m=0"),
        (7, 0, 1, "n=7, m=0"),
        # Random valid cases
        (6, 1, 57, "n=6, m=1"),
        (6, 2, 302, "n=6, m=2"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, m_val, expected, description) in enumerate(edge_cases):
        cocotb.log.info(f"\nEdge Test {i+1}: {description}")
        cocotb.log.info(f"  Input: n={n_val}, m={m_val}, Expected: {expected}")
        
        try:
            # Start computation
            await start_computation(dut, n_val, m_val)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"EDGE SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} edge case(s) failed")