import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
CHAR_WIDTH = 8
MAX_STRING_LEN = 16
MAX_STACK_DEPTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# ASCII codes for parentheses
ASCII_LPAREN = ord('(')
ASCII_RPAREN = ord(')')
ASCII_LBRACE = ord('{')
ASCII_RBRACE = ord('}')
ASCII_LBRACK = ord('[')
ASCII_RBRACK = ord(']')
ASCII_NULL = 0

# Error codes
ERR_NONE = 0
ERR_UNDERFLOW = 1
ERR_UNMATCHED = 2
ERR_OVERFLOW = 3
ERR_INVALID = 4

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

async def write_string(dut, test_string):
    """Write string to DUT character by character."""
    # Pad string to MAX_STRING_LEN with nulls
    chars = [ord(c) for c in test_string]
    while len(chars) < MAX_STRING_LEN:
        chars.append(ASCII_NULL)
    
    # Write each character
    for char in chars:
        dut.char_in.value = char
        dut.write_en.value = 1
        await RisingEdge(dut.clk)
        dut.write_en.value = 0
        await RisingEdge(dut.clk)

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.write_en.value = 0
    dut.check_start.value = 0
    
    for _ in range(3):
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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_parenthesis_balancer(dut):
    """Test the parenthesis balancing module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (expression, expected_result, description)
    test_cases = [
        ("{()}[{}]", True, "Balanced: {()}[{}]"),
        ("{()}[{]", False, "Unmatched: {()}[{]"),
        ("{()}[{}][]({})", True, "Balanced: {()}[{}][]({})"),
        ("(", False, "Single opening"),
        ("())", False, "Extra closing"),
        ("", True, "Empty string"),
        ("()", True, "Simple pair"),
        ("[{}]", True, "Nested"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (expr, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        try:
            # Reset for clean state
            await reset_dut(dut)
            
            # Start input phase
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await RisingEdge(dut.clk)
            
            # Write string
            await write_string(dut, expr)
            
            # Pulse check_start
            dut.check_start.value = 1
            await RisingEdge(dut.clk)
            dut.check_start.value = 0
            await RisingEdge(dut.clk)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = bool(int(dut.result.value))
            
            # Check error code for debugging
            error_code = int(dut.error_code.value) if is_value_defined(dut.error_code.value) else -1
            
            if result != expected:
                raise TestFailure(
                    f"Expected {expected}, got {result}. "
                    f"Error code: {error_code}"
                )
            
            cocotb.log.info(f"  PASS: result={result}, error_code={error_code}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")