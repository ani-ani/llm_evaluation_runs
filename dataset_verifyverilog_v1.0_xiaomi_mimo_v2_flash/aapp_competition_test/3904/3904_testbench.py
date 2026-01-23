import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def string_to_bits(s, max_len=16):
    """Convert string of parentheses to integer bit representation."""
    value = 0
    for i in range(min(len(s), max_len)):
        if s[i] == '(':
            value |= (1 << i)
    return value

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
async def test_bracket_sequence(dut):
    """Test bracket sequence module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (string, expected_result, description)
    # Note: string length must be <=16, longer strings are truncated
    test_cases = [
        ("))((())(", 6, "Example 1: length 8, cost 6"),
        ("(()", -1, "Example 2: unequal counts"),
        ("(", -1, "Example 3: unequal counts"),
        ("))(", 4, "Example 4: length 4, cost 4"),
        ("()()", 0, "Example 5: already correct"),
        (")()(", 4, "Example 6: length 4, cost 4"),
        (")()()()()(", 10, "Example 7: length 10, cost 10"),
        ("))))((((", 8, "Example 8: length 8, cost 8"),
        ("())(((()))", 2, "Example 9: length 10, cost 2"),
        ("()", 0, "Simple correct"),
        ("((()))", 0, "Nested correct"),
        (")(", 2, "Simple incorrect"),
        ("))))", -1, "All closing"),
        ("((((", -1, "All opening"),
        ("()()()()()", 0, "Multiple pairs"),
        (")))(((()))", 8, "Complex case"),
        ("(())(()", 2, "One extra opening"),
        (")()()()()", 10, "Starting with closing"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_string, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: '{test_string}'")
        
        try:
            # Convert string to bits
            string_bits = string_to_bits(test_string, 16)
            
            # Assign string value
            dut.string_bits.value = string_bits
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Handle -1 (0xFFFF) for impossible cases
            if expected == -1:
                if result != 0xFFFF:
                    raise TestFailure(f"Expected -1 (0xFFFF), got {result}")
            else:
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result if expected != -1 else -1}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")