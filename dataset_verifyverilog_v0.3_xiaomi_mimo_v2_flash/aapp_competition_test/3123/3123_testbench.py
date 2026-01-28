import cocotb
from cocotb.triggers import Timer, RisingEdge
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

async def reset_dut(dut):
    """Standard reset sequence."""
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10):
    """Wait for done signal."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure("Timeout waiting for done signal")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_quotations_solver(dut):
    """Test the simplified quotations solver."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, [a0, a1, a2], expected_k, description)
    # Scaled down problem: n <= 3, a_i <= 3
    test_cases = [
        (2, [1, 1], 1, "Valid 1-quotation: ''"),
        (2, [2, 2], 0, "Invalid: needs inner quotes"),
        (3, [2, 1, 2], 2, "Valid 2-quotation: '' + 'X' + ''"),
        (3, [2, 2, 2], 0, "Invalid: middle not 1"),
        (3, [1, 1, 1], 0, "Invalid: outer < 2"),
        (1, [3], 0, "Invalid: single block"),
        (2, [1, 2], 0, "Invalid: mismatched"),
    ]
    
    passed = 0
    failed = 0
    
    for n, a_vals, expected, desc in test_cases:
        cocotb.log.info(f"Test: {desc}")
        
        # Set inputs
        dut.n.value = n
        dut.a_0.value = a_vals[0] if len(a_vals) > 0 else 0
        dut.a_1.value = a_vals[1] if len(a_vals) > 1 else 0
        dut.a_2.value = a_vals[2] if len(a_vals) > 2 else 0
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.max_k.value):
            raise TestFailure(f"max_k is undefined (X/Z)")
        
        result = int(dut.max_k.value)
        
        if result == expected:
            cocotb.log.info(f"  PASS: k = {result}")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
