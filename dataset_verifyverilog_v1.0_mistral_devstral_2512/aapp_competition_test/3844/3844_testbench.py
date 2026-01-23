import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        # Handle signed values - we assume unsigned here
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

# ============================================================================
# ARRAY WRITE HELPER
# ============================================================================

async def write_array(dut, values):
    """Write values to arr_0..arr_15, clamping to DATA_WIDTH."""
    for i in range(ARRAY_SIZE):
        if i < len(values):
            val = clamp_to_width(values[i], DATA_WIDTH)
            setattr(dut, f'arr_{i}', val)
        else:
            setattr(dut, f'arr_{i}', 0)

# ============================================================================
# RESET AND WAIT HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_game_outcome(dut):
    """Test the game_outcome module."""
    
    # Detect if sequential
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (values, expected_result, description)
    test_cases = [
        ([4, 5, 7], 1, "Three distinct cards, all odd counts"),
        ([1, 1], 0, "Two identical cards, even count"),
        ([5], 1, "Single card, odd count"),
        ([1, 1, 2, 2], 0, "Two pairs, all even"),
        ([1, 2, 2, 3, 3], 1, "One odd (1) and two pairs"),
        ([2, 2, 2, 3, 3], 1, "Triple (odd) and pair (even)"),
        ([1, 1, 1, 1], 0, "All same, even count"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (values, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        # Set len
        dut.len.value = len(values)
        
        # Write array values
        await write_array(dut, values)
        
        # Start computation
        if is_sequential:
            await start_computation(dut)
            await wait_for_done(dut)
        else:
            # Combinational - wait for propagation
            await Timer(100, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"  FAIL: Result is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
