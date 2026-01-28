import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
CHAR_WIDTH = 8
MAX_INPUT_LEN = 8
MAX_TOKENS = 4
MAX_TOKEN_LEN = 8
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
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(2):
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

async def write_string_to_input(dut, input_str):
    """Write string to input array, padding with zeros."""
    # Convert string to list of character codes
    chars = [ord(c) for c in input_str]
    
    # Pad or truncate to MAX_INPUT_LEN
    if len(chars) > MAX_INPUT_LEN:
        chars = chars[:MAX_INPUT_LEN]
    else:
        chars = chars + [0] * (MAX_INPUT_LEN - len(chars))
    
    # Write each character to input_string array
    for i in range(MAX_INPUT_LEN):
        dut.input_string[i].value = chars[i]

async def read_output_tokens(dut):
    """Read output tokens from DUT."""
    token_count = int(dut.token_count.value)
    tokens = []
    
    for t in range(min(token_count, MAX_TOKENS)):
        token_chars = []
        for c in range(MAX_TOKEN_LEN):
            val = dut.tokens[t][c].value
            if is_value_defined(val):
                char_val = int(val)
                if char_val != 0:
                    token_chars.append(chr(char_val))
                else:
                    break
            else:
                break
        tokens.append(''.join(token_chars))
    
    return tokens, token_count

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_string_splitter(dut):
    """Test the string splitter module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_tokens, description)
    test_cases = [
        ("python programming", ["python", "programming"], "Two words"),
        ("lists tuples strings", ["lists", "tuples", "strings"], "Three words"),
        ("write a program", ["write", "a", "program"], "Three short words"),
        ("hello", ["hello"], "Single word"),
        ("a b c d", ["a", "b", "c", "d"], "Four single characters"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_tokens, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: '{input_str}'")
        cocotb.log.info(f"  Expected: {expected_tokens}")
        
        try:
            # Write input string
            await write_string_to_input(dut, input_str)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check error flag
            if is_value_defined(dut.error.value) and int(dut.error.value) == 1:
                raise TestFailure(f"Error flag asserted")
            
            # Read output tokens
            result_tokens, token_count = await read_output_tokens(dut)
            
            # Verify token count
            if token_count != len(expected_tokens):
                raise TestFailure(f"Token count mismatch: expected {len(expected_tokens)}, got {token_count}")
            
            # Verify each token
            for idx, (expected, actual) in enumerate(zip(expected_tokens, result_tokens)):
                if actual != expected:
                    raise TestFailure(f"Token {idx}: expected '{expected}', got '{actual}'")
            
            cocotb.log.info(f"  PASS: Got {result_tokens}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
