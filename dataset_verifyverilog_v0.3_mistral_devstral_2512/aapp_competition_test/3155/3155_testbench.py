import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 16
N_WIDTH = 7
K_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_binomial_solver(dut):
    """Test the binomial_solver module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (X, expected_n, expected_k, description)
    # These correspond to entries in the precomputed ROM
    test_cases = [
        (10, 5, 2, "C(5,2)=10"),
        (210, 10, 4, "C(10,4)=210"),
        (1, 0, 0, "C(0,0)=1"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (X, expected_n, expected_k, description) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {description}")
        
        # Set input X
        dut.X.value = X
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read outputs
        if not (is_value_defined(dut.n.value) and is_value_defined(dut.k.value)):
            dut._log.error(f"  FAIL: Output n or k is undefined (X/Z)")
            failed += 1
            continue
        
        actual_n = int(dut.n.value)
        actual_k = int(dut.k.value)
        
        if actual_n == expected_n and actual_k == expected_k:
            dut._log.info(f"  PASS: n={actual_n}, k={actual_k}")
            passed += 1
        else:
            dut._log.error(f"  FAIL: Expected ({expected_n}, {expected_k}), got ({actual_n}, {actual_k})")
            failed += 1
        
        # Wait one cycle before next test
        await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")