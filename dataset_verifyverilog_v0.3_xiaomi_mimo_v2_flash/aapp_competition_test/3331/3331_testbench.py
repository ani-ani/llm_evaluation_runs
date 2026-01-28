import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4  # A, B, P are 4-bit values
RESULT_WIDTH = 8
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
async def test_horse_chase(dut):
    """Test the horse chase minimax solver."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (A, B, P, expected_minutes, description)
    # These match the problem examples
    test_cases = [
        (4, 3, 2, 3, "L=5: A=4, B=3, P=2"),
        (4, 2, 3, 3, "L=5: A=4, B=2, P=3"),
        # Additional test cases would be added here
        # For L=16 max, we can test various positions
        (0, 15, 7, 8, "Spanning the trail"),
        (1, 2, 3, 1, "Adjacent positions"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (A, B, P, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        try:
            # Clamp values to 4-bit width
            A_val = clamp_to_width(A, DATA_WIDTH)
            B_val = clamp_to_width(B, DATA_WIDTH)
            P_val = clamp_to_width(P, DATA_WIDTH)
            
            # Assign inputs
            dut.A.value = A_val
            dut.B.value = B_val
            dut.P.value = P_val
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.minutes.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.minutes.value)
            
            # Check result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: minutes = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# ADDITIONAL TEST: Verify combinational lookup timing
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_lookup_combinational(dut):
    """Verify that lookup completes within one cycle after start."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test case: A=4, B=3, P=2
    dut.A.value = 4
    dut.B.value = 3
    dut.P.value = 2
    
    # Pulse start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait one cycle for lookup
    await RisingEdge(dut.clk)
    
    # Check done is asserted
    if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
        raise TestFailure("Done not asserted after lookup cycle")
    
    # Check result is correct
    if int(dut.minutes.value) != 3:
        raise TestFailure(f"Lookup failed: expected 3, got {int(dut.minutes.value)}")
    
    cocotb.log.info("Combinational lookup test passed")
