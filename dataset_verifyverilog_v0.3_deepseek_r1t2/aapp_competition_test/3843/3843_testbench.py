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

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

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
# TESTBENCH CONFIGURATION
# ============================================================================

DATA_WIDTH = 32          # For n and m
RESULT_WIDTH = 32        # For result
CLK_PERIOD_NS = 10       # Clock period in ns
MAX_CYCLES = 10000       # Timeout for sequential operations

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

async def start_computation(dut, n, m):
    """Start computation with given n and m."""
    dut.n.value = n
    dut.m.value = m
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_robbers_watch(dut):
    """Test the RobbersWatch module with provided test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, m, expected_result)
    test_cases = [
        (2, 3, 4),
        (8, 2, 5),
        (1, 1, 0),
        (1, 2, 1),
        (8, 8, 0),
        (50, 50, 0),
        (344, 344, 0),
        (282475250, 282475250, 0),
        (8, 282475250, 0),
        (1000000000, 1000000000, 0),
        (16808, 7, 720),
        (2402, 50, 0),
        (343, 2401, 5040),
        (1582, 301, 2874),
        (421414245, 4768815, 0),
        (2401, 343, 5040),
        (2, 1, 1),
        (282475250, 8, 0),
        (8, 7, 35),
        (50, 7, 120),
        (16808, 8, 0),
        (2402, 49, 720),
        (123, 123, 360),
        (123, 456, 150),
        (1, 9, 0),
        (1, 10, 1),
        (50, 67, 6),
        (7, 117649, 5040),
        (2400, 342, 5040),
        (2400, 227, 3360),
        (117648, 5, 3600),
        (16808, 41, 0),
        (3, 16808, 240),
        (823542, 3, 0),
        (3, 823544, 0),
        (117650, 5, 0),
        (50, 50, 40),
        (50, 3, 0),
        (2402, 343, 0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, m, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, m={m}, expected={expected}")
        
        # Start computation
        await start_computation(dut, n, m)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"  FAIL: result is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
        
        # Wait for one cycle before next test
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")