import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
P_MAX = 20
N_MAX = 3
M_MAX = 3
DATA_WIDTH = 4
CLK_PERIOD_NS = 10

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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_sequence(dut, sequence, p):
    """Write sequence to dut.seq array and set p."""
    for i in range(P_MAX):
        if i < p:
            dut.seq[i].value = clamp_to_width(sequence[i], DATA_WIDTH)
        else:
            dut.seq[i].value = 0
    dut.p.value = p

async def read_result(dut):
    """Read the result signals."""
    found = safe_int(dut.found.value)
    a_out = safe_int(dut.a_out.value)
    b_out = safe_int(dut.b_out.value)
    c_out = safe_int(dut.c_out.value)
    n_out = safe_int(dut.n_out.value)
    m_out = safe_int(dut.m_out.value)
    return found, a_out, b_out, c_out, n_out, m_out

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_triple_correlation(dut):
    """Test the triple correlation module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (sequence, p, expected_found, expected_a, expected_b, expected_c, expected_n, expected_m, description)
    test_cases = [
        # Example from problem
        ([
            4, 7, 9, 5, 9, 3, 5, 0, 0, 1, 7, 8, 5, 0, 2, 6, 3, 5, 4, 4,
            4, 6, 3, 3, 2, 7, 1, 8, 7, 8, 7, 6, 1, 1, 7, 2, 5, 4, 7, 2,
            0, 4, 4, 5, 8, 3, 0, 6, 9, 3, 2, 6, 6, 8, 5, 2, 5, 1, 2, 7,
            2, 4, 1, 0, 0, 4, 9, 1, 8, 7, 5, 0, 4, 4, 8, 4, 3, 2, 6, 8,
            8, 5, 6, 7, 0, 9, 7, 0, 3, 6, 1, 4, 4, 1, 2, 3, 2, 6, 9, 9
         ], 100, 1, 4, 4, 3, 1, 3, "Example from problem"),
        # No correlation
        ([1, 2, 3, 1, 2, 2, 1, 1, 3, 0], 10, 0, 0, 0, 0, 0, 0, "No correlation"),
    ]
    
    passed = 0
    failed = 0
    
    for seq, p, exp_found, exp_a, exp_b, exp_c, exp_n, exp_m, desc in test_cases:
        dut._log.info(f"Test: {desc}")
        
        try:
            # Write sequence and p
            await write_sequence(dut, seq, p)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            found, a_out, b_out, c_out, n_out, m_out = await read_result(dut)
            
            # Check
            if found != exp_found:
                raise TestFailure(f"Found mismatch: expected {exp_found}, got {found}")
            
            if found == 1:
                if a_out != exp_a or b_out != exp_b or c_out != exp_c or n_out != exp_n or m_out != exp_m:
                    raise TestFailure(f"Correlation mismatch: expected ({exp_a},{exp_n},{exp_b},{exp_m},{exp_c}), got ({a_out},{n_out},{b_out},{m_out},{c_out})")
            
            dut._log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")