import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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
# CONFIGURATION
# ============================================================================

DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 32
MOD = 1000000007
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    """Wait for done signal with timeout."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

async def start_computation(dut, N, a_values, b_values):
    """Set inputs and start computation."""
    dut.N.value = N
    
    # Set a_i values
    for i in range(ARRAY_SIZE):
        if i < len(a_values):
            dut.a_i[i].value = clamp_to_width(a_values[i], DATA_WIDTH)
        else:
            dut.a_i[i].value = 0
    
    # Set b_i values
    for i in range(ARRAY_SIZE):
        if i < len(b_values):
            dut.b_i[i].value = clamp_to_width(b_values[i], DATA_WIDTH)
        else:
            dut.b_i[i].value = 0
    
    # Pulse start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bipartite_battle(dut):
    """Test the BipartiteBattle module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (N, a_values, b_values, expected_result, description)
    test_cases = [
        (1, [1], [1], 1, "Single graph (1,1): cnt=1, total_edges=1, exponent=0, 2^0=1"),
        (1, [1], [2], 0, "Single graph (1,2): cnt=0 -> result=0"),
        (2, [1, 1], [1, 1], 0, "Two graphs (1,1),(1,1): cnt=2 -> result=0"),
        (2, [1, 1], [1, 2], 4, "Mixed: (1,1) and (1,2): cnt=1, total_edges=1+2=3, exponent=2, 2^2=4"),
        (2, [1, 2], [1, 2], 0, "Two graphs (1,2),(1,2): cnt=0 -> result=0"),
        (0, [], [], 0, "Zero graphs: cnt=0 -> result=0"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, a_vals, b_vals, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Start computation
            await start_computation(dut, N, a_vals, b_vals)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")