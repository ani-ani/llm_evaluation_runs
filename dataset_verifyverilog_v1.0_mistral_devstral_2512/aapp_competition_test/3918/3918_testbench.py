import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
ARRAY_SIZE = 8
RESULT_WIDTH = 64
K_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000  # Enough for 64 operations

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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
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
# ARRAY WRITE HELPERS
# ============================================================================

async def write_array_a(dut, values):
    """Write values to array A port a_0..a_7."""
    for i, val in enumerate(values):
        if has_signal(dut, f'a_{i}'):
            # Clamp to ensure fits in 16-bit signed range
            clamped = clamp_to_width(val, DATA_WIDTH)
            dut._log.info(f"Writing a_{i} = {val} (clamped to {clamped})")
            getattr(dut, f'a_{i}').value = clamped
        else:
            raise TestFailure(f"Cannot find port: a_{i}")

async def write_array_b(dut, values):
    """Write values to array B port b_0..b_7."""
    for i, val in enumerate(values):
        if has_signal(dut, f'b_{i}'):
            clamped = clamp_to_width(val, DATA_WIDTH)
            dut._log.info(f"Writing b_{i} = {val} (clamped to {clamped})")
            getattr(dut, f'b_{i}').value = clamped
        else:
            raise TestFailure(f"Cannot find port: b_{i}")

async def write_k1_k2(dut, k1_val, k2_val):
    """Write k1 and k2 values."""
    if has_signal(dut, 'k1'):
        dut.k1.value = clamp_to_width(k1_val, K_WIDTH)
    else:
        raise TestFailure("Cannot find port: k1")
    
    if has_signal(dut, 'k2'):
        dut.k2.value = clamp_to_width(k2_val, K_WIDTH)
    else:
        raise TestFailure("Cannot find port: k2")

async def read_result(dut):
    """Read the result output."""
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    return int(dut.result.value)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_error(dut):
    """Test min_error module with scaled test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (array_a, array_b, k1, k2, expected_result, description)
    # Values are scaled to fit 16-bit signed range [-32768, 32767]
    test_cases = [
        # Original example 1: 2 0 0; A=[1,2], B=[2,3] -> 2
        ([1, 2, 0, 0, 0, 0, 0, 0], [2, 3, 0, 0, 0, 0, 0, 0], 0, 0, 2, "Example 1: No operations"),
        
        # Original example 2: 2 1 0; A=[1,2], B=[2,2] -> 0
        ([1, 2, 0, 0, 0, 0, 0, 0], [2, 2, 0, 0, 0, 0, 0, 0], 1, 0, 0, "Example 2: One operation"),
        
        # Original example 3: 2 5 7; A=[3,4], B=[14,4] -> 1
        ([3, 4, 0, 0, 0, 0, 0, 0], [14, 4, 0, 0, 0, 0, 0, 0], 5, 7, 1, "Example 3: Multiple operations"),
        
        # Additional tests
        ([0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0], 10, 5, 1, "All zero, odd remaining ops"),
        ([0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0], 10, 6, 0, "All zero, even remaining ops"),
        ([10, 10, 10, 10, 0, 0, 0, 0], [5, 5, 5, 5, 0, 0, 0, 0], 20, 0, 0, "Uniform reduction"),
        ([5, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0], 3, 0, 4, "Single element reduction"),
        ([-5, 5, 0, 0, 0, 0, 0, 0], [-10, 10, 0, 0, 0, 0, 0, 0], 5, 0, 0, "Mixed signs"),
        # Edge case: large numbers but few operations
        ([1000, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0], 5, 5, 990, "Large difference, few ops"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_a, arr_b, k1, k2, expected, description) in enumerate(test_cases):
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Test {i+1}: {description}")
        dut._log.info(f"  A = {arr_a[:8]}")
        dut._log.info(f"  B = {arr_b[:8]}")
        dut._log.info(f"  k1 = {k1}, k2 = {k2}")
        dut._log.info(f"  Expected = {expected}")
        
        try:
            # Write inputs
            await write_array_a(dut, arr_a)
            await write_array_b(dut, arr_b)
            await write_k1_k2(dut, k1, k2)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            result = await read_result(dut)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")