import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 9
CLK_PERIOD_NS = 10
MAX_CYCLES = 50

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

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(2):
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

async def start_computation(dut, n):
    """Start computation with input n."""
    dut.n.value = n
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_next_power_of_2(dut):
    """Test next_power_of_2 module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases from problem: (input, expected, description)
    test_cases = [
        (0, 1, "Boundary: n=0"),
        (1, 2, "Power of 2: n=1"),
        (2, 2, "Power of 2: n=2"),
        (3, 4, "Next power: n=3"),
        (4, 4, "Power of 2: n=4"),
        (5, 8, "Original test: n=5"),
        (7, 8, "Next power: n=7"),
        (8, 8, "Power of 2: n=8"),
        (15, 16, "Next power: n=15"),
        (16, 16, "Power of 2: n=16"),
        (17, 32, "Original test: n=17"),
        (31, 32, "Next power: n=31"),
        (32, 32, "Power of 2: n=32"),
        (127, 128, "Next power: n=127"),
        (128, 128, "Power of 2: n=128"),
        (255, 256, "Max value: n=255"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_input, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description} (input={n_input}, expected={expected})")
        
        try:
            # Start computation
            await start_computation(dut, n_input)
            
            # Wait for done
            await wait_for_done(dut)
            
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
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")