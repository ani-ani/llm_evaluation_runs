import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 12
ARRAY_SIZE = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
async def test_game_solver(dut):
    """Main test function for game_solver module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (N, numbers, expected_count)
    test_cases = [
        (1, [5, 0, 0, 0], 1),      # N=1, number=5 (odd) -> count=1
        (1, [4, 0, 0, 0], 0),      # N=1, number=4 (even) -> count=0
        (2, [1, 2, 0, 0], 1),      # N=2, [1,2] -> count=1
        (3, [3, 1, 5, 0], 3),      # Example 1: N=3, [3,1,5] -> count=3
        (4, [1, 2, 3, 4], 2),      # Example 2: N=4, [1,2,3,4] -> count=2
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, numbers, expected_count) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={N}, numbers={numbers}, expected={expected_count}")
        
        try:
            # Set inputs
            dut.N.value = N
            # Set numbers: we have 4 ports
            for j in range(4):
                if j < len(numbers):
                    dut.numbers[j].value = numbers[j]
                else:
                    dut.numbers[j].value = 0
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.count.value):
                raise TestFailure(f"Count is undefined (X/Z)")
            
            count = int(dut.count.value)
            
            if count != expected_count:
                raise TestFailure(f"Expected {expected_count}, got {count}")
            
            cocotb.log.info(f"  PASS: count = {count}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")