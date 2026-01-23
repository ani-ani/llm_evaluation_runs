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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================

DATA_WIDTH = 8
MAX_N = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# ARRAY WRITE HELPERS
# ============================================================================

async def write_array(dut, values, max_size=MAX_N):
    """Write array values to the DUT individual ports."""
    # Ensure we don't exceed max_size
    values = values[:max_size]
    
    # Write to each port p_0 through p_15
    for i in range(max_size):
        if i < len(values):
            val = clamp_to_width(values[i], DATA_WIDTH)
        else:
            val = 0
        
        port_name = f'p_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = val
        else:
            raise TestFailure(f"Port {port_name} not found")

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
async def test_garland_minimizer(dut):
    """Test the garland minimizer module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, p_array, expected_result, description)
    test_cases = [
        (5, [0, 5, 0, 2, 3], 2, "Example 1: n=5, [0,5,0,2,3]"),
        (7, [1, 0, 0, 5, 0, 0, 2], 1, "Example 2: n=7, [1,0,0,5,0,0,2]"),
        (1, [0], 0, "Single missing bulb"),
        (3, [1, 2, 3], 2, "All fixed: 1,2,3 -> 1-2 diff, 2-3 diff -> 2"),
        (4, [0, 0, 0, 0], 0, "All missing: can arrange as all same parity"),
        (8, [0, 0, 0, 0, 0, 0, 0, 0], 0, "8 missing: all same parity"),
        (2, [1, 0], 0, "Two elements: place even after odd, but only one pair"),
        (6, [2, 0, 0, 5, 0, 3], 2, "Mixed case"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, p_array, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Pad array to length 16
            padded_p = p_array + [0] * (MAX_N - len(p_array))
            
            # Write inputs
            dut.n.value = n
            await write_array(dut, padded_p)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
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