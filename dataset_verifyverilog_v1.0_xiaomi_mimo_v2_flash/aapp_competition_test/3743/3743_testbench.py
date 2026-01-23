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

async def start_computation(dut, n_val):
    """Start computation with given n."""
    dut.n_in.value = n_val
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_max_colors(dut):
    """Test the max_colors module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, expected_result, description)
    test_cases = [
        (1, 1, "n=1"),
        (2, 2, "n=2 (prime)"),
        (3, 3, "n=3 (prime)"),
        (4, 2, "n=4 (2^2)"),
        (5, 5, "n=5 (prime)"),
        (6, 1, "n=6 (2*3)"),
        (7, 7, "n=7 (prime)"),
        (8, 2, "n=8 (2^3)"),
        (9, 3, "n=9 (3^2)"),
        (16, 2, "n=16 (2^4)"),
        (25, 5, "n=25 (5^2)"),
        (27, 3, "n=27 (3^3)"),
        (30, 1, "n=30 (2*3*5)"),
        (49, 7, "n=49 (7^2)"),
        (121, 11, "n=121 (11^2)"),
        (256, 2, "n=256 (2^8)"),
        (65535, 1, "n=65535 (3*5*17*257)"),
        (65537, 65537, "n=65537 (prime)"),
        (65521, 65521, "n=65521 (prime)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Start computation
            await start_computation(dut, n)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
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