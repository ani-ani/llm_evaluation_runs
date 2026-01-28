import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
BASE_WIDTH = 8      # 8-bit base
EXP_WIDTH = 5       # 5-bit exponent (max 31 iterations)
RESULT_WIDTH = 32   # 32-bit result
CLK_PERIOD_NS = 10
MAX_CYCLES = 100    # Enough for 31 iterations + overhead

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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_power_module(dut):
    """Test the power computation module."""
    
    # Verify required signals exist
    required_signals = ['clk', 'rst_n', 'start', 'base', 'exponent', 'result', 'done']
    for sig in required_signals:
        if not has_signal(dut, sig):
            raise TestFailure(f"Required signal '{sig}' not found")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (base, exponent, expected_result, description)
    test_cases = [
        (3, 4, 81, "3^4 = 81"),
        (2, 3, 8, "2^3 = 8"),
        (5, 5, 3125, "5^5 = 3125"),
        (1, 10, 1, "1^10 = 1"),
        (7, 0, 1, "7^0 = 1 (exponent=0)"),
        (0, 5, 0, "0^5 = 0 (base=0)"),
        (10, 1, 10, "10^1 = 10 (exponent=1)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (base, exponent, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Set inputs
            dut.base.value = clamp_to_width(base, BASE_WIDTH)
            dut.exponent.value = clamp_to_width(exponent, EXP_WIDTH)
            
            # Wait one cycle for inputs to stabilize
            await RisingEdge(dut.clk)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result on the cycle done is high
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
            # Wait one cycle before next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            # Reset before next test
            await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")