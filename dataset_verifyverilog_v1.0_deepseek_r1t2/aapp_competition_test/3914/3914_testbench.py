import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 16
RESULT_WIDTH = 8
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# TESTBENCH CORE
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_curfew_enforcement(dut):
    """Test curfew enforcement module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, d, b, a, expected_result)
    test_cases = [
        # Example 1: n=5, d=1, b=1, a=[1,0,0,0,4] -> result=1
        (5, 1, 1, [1, 0, 0, 0, 4], 1),
        # Example 2: n=6, d=1, b=2, a=[3,8,0,1,0,0] -> result=2
        (6, 1, 2, [3, 8, 0, 1, 0, 0], 2),
        # Additional test cases from provided examples
        (5, 1, 1, [1, 1, 0, 3, 0], 0),
        (5, 1, 1, [4, 0, 0, 1, 0], 1),
        (2, 1, 1, [0, 2], 0),
        # Simplified test case for hardware (smaller numbers)
        (4, 2, 1, [1, 0, 0, 3], 0),
        (8, 1, 2, [4, 4, 4, 4, 4, 4, 4, 4], 0),  # All perfect
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (n, d, b, a_list, expected) in enumerate(test_cases):
        # Pad array to 16 elements
        a_padded = a_list + [0] * (ARRAY_SIZE - len(a_list))
        
        dut._log.info(f"Test {test_idx+1}: n={n}, d={d}, b={b}, a={a_list}")
        
        # Set inputs
        dut.n.value = n
        dut.d.value = d
        dut.b.value = b
        
        # Assign array elements individually (following RULE B2)
        for i in range(ARRAY_SIZE):
            dut.a[i].value = clamp_to_width(a_padded[i], DATA_WIDTH)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with timeout
        cycles = 0
        done_found = False
        while cycles < MAX_CYCLES:
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_found = True
                break
            cycles += 1
        
        if not done_found:
            dut._log.error(f"  FAIL: Done not asserted after {MAX_CYCLES} cycles")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            dut._log.error(f"  FAIL: Result is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        # Verify result
        if result == expected:
            dut._log.info(f"  PASS: result={result}")
            passed += 1
        else:
            dut._log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*60}")
    dut._log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
