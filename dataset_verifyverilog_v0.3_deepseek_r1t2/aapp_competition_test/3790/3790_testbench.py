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
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
# TEST FUNCTION
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_longest_non_decreasing_subsequence(dut):
    """Test longest non-decreasing subsequence in repeated array."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, T, base_array, expected)
    # Format: (n, T, [base_array_0, base_array_1, ..., base_array_7], expected_result)
    test_cases = [
        (4, 3, [3, 1, 4, 2, 0, 0, 0, 0], 5),   # Original example
        (1, 8, [42, 0, 0, 0, 0, 0, 0, 0], 8),   # Single element repeated
        (2, 8, [1, 2, 0, 0, 0, 0, 0, 0], 16),   # Strictly increasing
        (2, 8, [2, 1, 0, 0, 0, 0, 0, 0], 8),    # Decreasing base
        (3, 5, [3, 2, 1, 0, 0, 0, 0, 0], 5),    # All decreasing
        (4, 2, [1, 3, 2, 4, 0, 0, 0, 0], 6),    # Mixed
        (1, 1, [5, 0, 0, 0, 0, 0, 0, 0], 1),    # Single element, single copy
        (8, 1, [1, 2, 3, 4, 5, 6, 7, 8], 8),    # Single copy, strictly increasing
        (8, 1, [8, 7, 6, 5, 4, 3, 2, 1], 1),    # Single copy, strictly decreasing
        (2, 4, [1, 1, 0, 0, 0, 0, 0, 0], 8),    # All equal
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, T, base_array, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, T={T}, base_array={base_array[:n]}, expected={expected}")
        
        try:
            # Set inputs
            dut.n.value = n
            dut.T.value = T
            
            # Set base array elements (all 8 ports)
            for j in range(8):
                port_name = f'base_array_{j}'
                if has_signal(dut, port_name):
                    # Clamp to 8-bit width
                    val = clamp_to_width(base_array[j], DATA_WIDTH)
                    getattr(dut, port_name).value = val
            
            # Wait for reset to propagate
            await RisingEdge(dut.clk)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
            # Wait for done to go low
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")