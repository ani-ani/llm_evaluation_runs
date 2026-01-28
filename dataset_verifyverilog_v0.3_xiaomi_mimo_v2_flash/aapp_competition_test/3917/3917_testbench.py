import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
N_WIDTH = 4
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
    if value < 0:
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_min_distance(dut):
    """Test the min_distance module."""
    
    # Start clock if present (combinational module, but check)
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Test cases: (n, [a0..a7], expected_result, description)
    test_cases = [
        # Example 1: n=4, [1,0,0,-1] -> output 1
        (4, [1,0,0,-1,0,0,0,0], 1, "Example 1"),
        # Example 2: n=2, [1,-1] -> output 2
        (2, [1,-1,0,0,0,0,0,0], 2, "Example 2"),
        # Additional tests
        (2, [5,5,0,0,0,0,0,0], 4, "Two equal positive"),
        (3, [10,10,-10,0,0,0,0,0], 4, "Three values"),
        (8, [1,2,3,4,5,6,7,8], 5, "Linear increasing"),
        (5, [100,-100,50,-50,0,0,0,0], 101, "Mixed values"),
        (6, [10,10,10,10,10,10,0,0], 101, "Repeated 10"),
        (3, [0,10000,10000,0,0,0,0,0], 100000001, "Large values"),
        (2, [0,100,0,0,0,0,0,0], 10001, "Zero and 100"),
        (4, [0,100,100,-200,0,0,0,0], 9, "Complex prefix"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, a_vals, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        # Set inputs
        dut.n.value = n
        
        # Set array values individually
        for idx, val in enumerate(a_vals):
            signal_name = f'a{idx}'
            if has_signal(dut, signal_name):
                # Clamp to 8-bit signed
                clamped = clamp_to_width(val, DATA_WIDTH)
                # Convert to signed representation if negative
                if val < 0:
                    clamped = from_signed(val, DATA_WIDTH)
                getattr(dut, signal_name).value = clamped
        
        # Wait for combinational logic to settle
        await Timer(100, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"  FAIL: Result is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        # For large numbers, the result might be interpreted as unsigned
        # Convert to signed if needed (but squared distance is always positive)
        
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