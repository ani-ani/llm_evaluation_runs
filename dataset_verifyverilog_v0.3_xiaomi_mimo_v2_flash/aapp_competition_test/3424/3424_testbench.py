import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
MAX_B = 256
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_find_base(dut):
    """Main test function for find_base module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (y, l, expected_b, description)
    test_cases = [
        (32, 20, 16, "Example 1: 32 in base 16 = 20 >= 20"),
        (2016, 100, 42, "Example 2: 2016 in base 42 = 160 >= 100"),
        (100, 10, 100, "Max base: 100 in base 100 = 10"),
        (100, 100, 10, "Smaller base needed: 100 in base 10 = 100"),
        (64, 8, 64, "64 in base 64 = 10 >= 8"),
        (64, 12, 8, "64 in base 8 = 100 >= 12"),
        (50, 25, 25, "50 in base 25 = 20 >= 25? No. 50 in base 20 = 210 >= 25, b=20"),
        (200, 50, 40, "200 in base 40 = 50 >= 50"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (y, l, expected_b, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: y={y}, l={l}, expected_b={expected_b}")
        
        try:
            # Set inputs
            dut.y.value = clamp_to_width(y, DATA_WIDTH)
            dut.l.value = clamp_to_width(l, DATA_WIDTH)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.b.value):
                raise TestFailure(f"Output b is undefined (X/Z)")
            
            if not is_value_defined(dut.valid.value):
                raise TestFailure(f"Output valid is undefined (X/Z)")
            
            result_b = int(dut.b.value)
            result_valid = int(dut.valid.value)
            
            if not result_valid:
                raise TestFailure(f"No valid base found (valid=0)")
            
            if result_b != expected_b:
                raise TestFailure(f"Expected {expected_b}, got {result_b}")
            
            cocotb.log.info(f"  PASS: b={result_b}")
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