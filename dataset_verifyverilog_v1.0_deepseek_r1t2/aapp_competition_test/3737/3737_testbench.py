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
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
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
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_steward_support(dut):
    """Test the steward support module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, [arr_0..arr_7], expected_result)
    test_cases = [
        # From problem examples
        (2, [1, 5, 0, 0, 0, 0, 0, 0], 0),
        (3, [1, 2, 5, 0, 0, 0, 0, 0], 1),
        (4, [1, 2, 3, 4, 0, 0, 0, 0], 2),
        (8, [7, 8, 9, 4, 5, 6, 1, 2], 6),
        
        # Edge cases
        (1, [1, 0, 0, 0, 0, 0, 0, 0], 0),
        (1, [100, 0, 0, 0, 0, 0, 0, 0], 0),
        (3, [2, 2, 2, 0, 0, 0, 0, 0], 0),
        (5, [1, 1, 1, 1, 1, 0, 0, 0], 0),
        (6, [1, 1, 3, 3, 2, 2, 0, 0], 2),
        (4, [1, 1, 2, 5, 0, 0, 0, 0], 1),
        (3, [0, 0, 0, 0, 0, 0, 0, 0], 0),
        (5, [0, 0, 0, 0, 0, 0, 0, 0], 0),
        (5, [1, 1, 1, 1, 5, 0, 0, 0], 0),
        (5, [1, 1, 2, 3, 3, 0, 0, 0], 1),
        (3, [1, 1, 3, 0, 0, 0, 0, 0], 0),
        (3, [2, 2, 3, 0, 0, 0, 0, 0], 0),
        (1, [6, 0, 0, 0, 0, 0, 0, 0], 0),
        (5, [1, 5, 3, 5, 1, 0, 0, 0], 1),
        (7, [1, 2, 2, 2, 2, 2, 3, 0], 1),
        (4, [2, 2, 2, 2, 0, 0, 0, 0], 0),
        (8, [2, 2, 2, 3, 4, 5, 6, 6], 6),
        
        # Additional complex cases
        (3, [5, 5, 5, 0, 0, 0, 0, 0], 0),
        (4, [1, 1, 2, 2, 0, 0, 0, 0], 0),
        (4, [1, 2, 2, 3, 0, 0, 0, 0], 1),
        (5, [1, 2, 3, 4, 5, 0, 0, 0], 3),
        (6, [1, 1, 2, 2, 3, 3, 0, 0], 2),
        (8, [1, 1, 1, 2, 3, 3, 3, 4], 2),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, values, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, values={values[:n]}, expected={expected}")
        
        try:
            # Set n
            dut.n.value = n
            
            # Set array elements individually
            dut.arr_0.value = clamp_to_width(values[0], 8)
            dut.arr_1.value = clamp_to_width(values[1], 8)
            dut.arr_2.value = clamp_to_width(values[2], 8)
            dut.arr_3.value = clamp_to_width(values[3], 8)
            dut.arr_4.value = clamp_to_width(values[4], 8)
            dut.arr_5.value = clamp_to_width(values[5], 8)
            dut.arr_6.value = clamp_to_width(values[6], 8)
            dut.arr_7.value = clamp_to_width(values[7], 8)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut, max_cycles=100)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")