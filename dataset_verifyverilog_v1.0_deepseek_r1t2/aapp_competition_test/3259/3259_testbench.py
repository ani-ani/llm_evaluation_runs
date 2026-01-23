import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 20
ARRAY_SIZE = 16
RESULT_WIDTH = 32
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

async def start_computation(dut, cmd_type, L, R, A=0, B=0):
    """Pulse start signal for one cycle and set command inputs."""
    dut.cmd_type.value = cmd_type
    dut.L.value = L
    dut.R.value = R
    dut.A.value = A
    dut.B.value = B
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_aladin_device(dut):
    """Main test function for Aladin device."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case 1: Initial query should be 0
    dut._log.info("Test 1: Initial query for boxes 1 to 6")
    await start_computation(dut, cmd_type=2, L=1, R=6)
    await wait_for_done(dut)
    result = int(dut.result.value)
    if result != 0:
        raise TestFailure(f"Expected 0, got {result}")
    dut._log.info(f"  PASS: result = {result}")
    
    # Test case 2: Update: 1 1 5 1 2
    dut._log.info("Test 2: Update L=1, R=5, A=1, B=2")
    await start_computation(dut, cmd_type=1, L=1, R=5, A=1, B=2)
    await wait_for_done(dut)
    
    # Test case 3: Query after update
    dut._log.info("Test 3: Query boxes 1 to 6 after update")
    await start_computation(dut, cmd_type=2, L=1, R=6)
    await wait_for_done(dut)
    result = int(dut.result.value)
    if result != 3:
        raise TestFailure(f"Expected 3, got {result}")
    dut._log.info(f"  PASS: result = {result}")
    
    # Test case 4: Update: 1 1 4 3 4
    dut._log.info("Test 4: Update L=1, R=4, A=3, B=4")
    await start_computation(dut, cmd_type=1, L=1, R=4, A=3, B=4)
    await wait_for_done(dut)
    
    # Test case 5: Query each box
    dut._log.info("Test 5: Query each box individually")
    expected = [3, 2, 1, 0]
    for i in range(1, 5):
        await start_computation(dut, cmd_type=2, L=i, R=i)
        await wait_for_done(dut)
        result = int(dut.result.value)
        if result != expected[i-1]:
            raise TestFailure(f"Box {i}: expected {expected[i-1]}, got {result}")
        dut._log.info(f"  Box {i}: {result} [OK]")
    
    # Additional test: Update beyond array bounds
    dut._log.info("Test 6: Update L=15, R=20 (only boxes 15,16 should be updated)")
    await start_computation(dut, cmd_type=1, L=15, R=20, A=5, B=7)
    await wait_for_done(dut)
    
    # Query boxes 15 and 16
    await start_computation(dut, cmd_type=2, L=15, R=16)
    await wait_for_done(dut)
    result = int(dut.result.value)
    # Box 15: step = (15-15+1)=1, value = 1*5 % 7 = 5
    # Box 16: step = (16-15+1)=2, value = 2*5 % 7 = 10 % 7 = 3
    # Sum = 5 + 3 = 8
    if result != 8:
        raise TestFailure(f"Expected 8, got {result}")
    dut._log.info(f"  PASS: result = {result}")
    
    # Test: Query beyond array bounds
    dut._log.info("Test 7: Query L=15, R=25 (should only sum boxes 15,16)")
    await start_computation(dut, cmd_type=2, L=15, R=25)
    await wait_for_done(dut)
    result = int(dut.result.value)
    if result != 8:
        raise TestFailure(f"Expected 8, got {result}")
    dut._log.info(f"  PASS: result = {result}")
    
    dut._log.info("All tests passed!")