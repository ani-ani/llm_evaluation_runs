import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
N_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut, n_val, m_val):
    dut.n.value = n_val
    dut.m.value = m_val
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# PYTHON REFERENCE IMPLEMENTATION
# ============================================================================

def totient(m):
    """Compute Euler's totient function."""
    if m == 1:
        return 1
    result = m
    i = 2
    temp = m
    while i * i <= temp:
        if temp % i == 0:
            while temp % i == 0:
                temp //= i
            result -= result // i
        i += 1
    if temp > 1:
        result -= result // temp
    return result

def exponial_mod_py(n, m):
    """Python reference for exponial(n) mod m."""
    if m == 1:
        return 0
    if n == 1:
        return 1
    if n == 2:
        return 2 % m
    if n == 3:
        return 9 % m
    if n == 4:
        return pow(4, 9, m)  # 262144 % m
    
    phi = totient(m)
    
    # Compute lower bound for exponial(n-1)
    lb = 1
    for i in range(n-1, 0, -1):
        lb = i ** lb
        if lb > phi:
            break
    
    k = exponial_mod_py(n-1, phi)
    
    if lb >= phi:
        return pow(n, k + phi, m)
    else:
        return pow(n, k, m)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_exponial_mod(dut):
    """Test exponial modular computation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, m, expected_result)
    test_cases = [
        (1, 42, 1),
        (2, 42, 2),
        (3, 42, 9),
        (4, 42, 262144 % 42),
        (5, 123456789, 16317634),
        (1, 1, 0),
        (2, 1, 0),
        (3, 1, 0),
        (5, 265, 39),
        (6, 1000000007, 999999937),  # Known test case
    ]
    
    passed = 0
    failed = 0
    
    for n_val, m_val, expected in test_cases:
        # Skip if n > 255 or m > 2^32-1 (our scaled limits)
        if n_val > 255 or m_val > 0xFFFFFFFF:
            cocotb.log.info(f"Skipping (n={n_val}, m={m_val}) - exceeds scaled limits")
            continue
        
        cocotb.log.info(f"Testing: exponial({n_val}) mod {m_val}")
        
        try:
            # Start computation
            await start_computation(dut, n_val, m_val)
            
            # Wait for completion
            await wait_for_done(dut, max_cycles=1000)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Wait one cycle between tests
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")