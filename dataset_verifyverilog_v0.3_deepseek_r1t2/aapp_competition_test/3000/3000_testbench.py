import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
TOKEN_WIDTH = 10
TOKEN_COUNT_MAX = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# Token type encoding
TYPE_NUMBER = 0
TYPE_OPEN = 1
TYPE_CLOSE = 2

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# TOKEN ENCODING FUNCTIONS
# ============================================================================

def encode_token(token_str):
    """Convert token string to (type, value) tuple."""
    if token_str == '(':
        return (TYPE_OPEN, 0)
    elif token_str == ')':
        return (TYPE_CLOSE, 0)
    else:
        num = int(token_str) % 256
        return (TYPE_NUMBER, num)

def pack_token(token_tuple):
    """Pack (type, value) tuple into 10-bit integer."""
    token_type, value = token_tuple
    return (token_type << 8) | value

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT."""
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

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_tokens(dut, token_values):
    """Write token values to individual port interface."""
    n = len(token_values)
    # Set token_count
    dut.token_count.value = n
    
    # Write tokens to individual ports
    for i in range(TOKEN_COUNT_MAX):
        port_name = f'token_{i}'
        if i < n:
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = token_values[i]
            else:
                raise TestFailure(f"Signal {port_name} not found")
        else:
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = 0

# ============================================================================
# TEST CASES (SCALED TO 8-BIT MOD 256)
# ============================================================================

# Test cases: (input_string, expected_result, description)
TEST_CASES = [
    (
        "2 3",
        5,
        "Simple addition: 2 + 3 = 5"
    ),
    (
        "( 2 ( 2 1 ) ) 3",
        9,
        "Nested: (2 * (2+1)) + 3 = 6 + 3 = 9"
    ),
    (
        "( 12 3 )",
        36,
        "Multiplication: 12 * 3 = 36"
    ),
    (
        "( 2 ) ( 3 )",
        5,
        "Separate groups: (2) + (3) = 2 + 3 = 5"
    ),
    (
        "( ( 2 3 ) )",
        5,
        "Double nested: ((2+3)) = 5"
    ),
    (
        "1 ( 0 ( 583920 ( 2839 82 ) ) )",
        1,
        "Complex: 1 + 0 * (240 * (23 * 82 % 256) % 256) % 256 = 1"
    ),
    (
        "42",
        42,
        "Single number"
    ),
    (
        "( 5 )",
        5,
        "Simple parentheses"
    ),
    (
        "1 2 3",
        6,
        "Multiple additions"
    ),
    (
        "( 2 3 4 )",
        24,
        "Multiple multiplications: 2*3*4 = 24"
    ),
]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_bracket_evaluator(dut):
    """Test the bracket sequence evaluator module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for test_idx, (input_str, expected, description) in enumerate(TEST_CASES):
        cocotb.log.info(f"\nTest {test_idx + 1}: {description}")
        cocotb.log.info(f"  Input: {input_str}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Parse input string into tokens
            token_strs = input_str.split()
            
            if len(token_strs) > TOKEN_COUNT_MAX:
                raise TestFailure(f"Test requires {len(token_strs)} tokens, max supported is {TOKEN_COUNT_MAX}")
            
            # Encode and pack tokens
            token_values = []
            for token_str in token_strs:
                token_tuple = encode_token(token_str)
                token_values.append(pack_token(token_tuple))
            
            # Write tokens to DUT
            await write_tokens(dut, token_values)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut, max_cycles=20)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Check error flag
            error_occurred = False
            if has_signal(dut, 'error') and is_value_defined(dut.error.value):
                if int(dut.error.value) == 1:
                    error_occurred = True
            
            if error_occurred:
                raise TestFailure("Error flag asserted")
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Test Summary: {passed}/{passed+failed} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# ERROR CASE TESTS
# ============================================================================

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_error_cases(dut):
    """Test error detection."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test 1: Mismatched brackets - extra closing
    cocotb.log.info("Testing mismatched brackets: )")
    token_values = [pack_token((TYPE_CLOSE, 0))]
    await write_tokens(dut, token_values)
    await start_computation(dut)
    await wait_for_done(dut, max_cycles=5)
    
    if has_signal(dut, 'error') and is_value_defined(dut.error.value):
        if int(dut.error.value) != 1:
            raise TestFailure("Error not detected for extra closing bracket")
    else:
        raise TestFailure("Error signal not found")
    
    cocotb.log.info("  Error correctly detected [PASS]")
    
    # Test 2: Mismatched brackets - extra opening
    cocotb.log.info("Testing mismatched brackets: ( ( 1 )")
    await reset_dut(dut)
    token_strs = ['(', '(', '1', ')']
    token_values = [pack_token(encode_token(t)) for t in token_strs]
    await write_tokens(dut, token_values)
    await start_computation(dut)
    await wait_for_done(dut, max_cycles=10)
    
    if has_signal(dut, 'error') and is_value_defined(dut.error.value):
        if int(dut.error.value) != 1:
            raise TestFailure("Error not detected for unbalanced parentheses")
    else:
        raise TestFailure("Error signal not found")
    
    cocotb.log.info("  Error correctly detected [PASS]")
    
    # Test 3: Stack overflow (depth > 4)
    cocotb.log.info("Testing stack overflow: ( ( ( ( ( 1 ) ) ) ) )")
    await reset_dut(dut)
    token_strs = ['(', '(', '(', '(', '(', '1', ')', ')', ')', ')', ')']
    token_values = [pack_token(encode_token(t)) for t in token_strs]
    await write_tokens(dut, token_values)
    await start_computation(dut)
    await wait_for_done(dut, max_cycles=15)
    
    if has_signal(dut, 'error') and is_value_defined(dut.error.value):
        if int(dut.error.value) != 1:
            raise TestFailure("Error not detected for stack overflow")
    else:
        raise TestFailure("Error signal not found")
    
    cocotb.log.info("  Error correctly detected [PASS]")
    
    cocotb.log.info("\nAll error case tests passed")

# ============================================================================
# BOUNDARY VALUE TESTS
# ============================================================================

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_boundary_values(dut):
    """Test boundary values and edge cases."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Test 1: Maximum value (255)
    cocotb.log.info("Testing maximum value: 255")
    await reset_dut(dut)
    token_values = [pack_token(encode_token('255'))]
    await write_tokens(dut, token_values)
    await start_computation(dut)
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    if result != 255:
        raise TestFailure(f"Max value test failed: expected 255, got {result}")
    cocotb.log.info(f"  Result: {result} [PASS]")
    
    # Test 2: Zero value
    cocotb.log.info("Testing zero value: 0")
    await reset_dut(dut)
    token_values = [pack_token(encode_token('0'))]
    await write_tokens(dut, token_values)
    await start_computation(dut)
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    if result != 0:
        raise TestFailure(f"Zero value test failed: expected 0, got {result}")
    cocotb.log.info(f"  Result: {result} [PASS]")
    
    # Test 3: Operation with zeros
    cocotb.log.info("Testing ( 0 5 )")
    await reset_dut(dut)
    token_strs = ['(', '0', '5', ')']
    token_values = [pack_token(encode_token(t)) for t in token_strs]
    await write_tokens(dut, token_values)
    await start_computation(dut)
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    expected = (0 * 5) % 256  # Multiplication mode
    if result != expected:
        raise TestFailure(f"Zero multiplication test failed: expected {expected}, got {result}")
    cocotb.log.info(f"  Result: {result} [PASS]")
    
    # Test 4: 16 tokens maximum
    cocotb.log.info("Testing maximum token count: 16")
    await reset_dut(dut)
    token_strs = ['1'] * 16
    token_values = [pack_token(encode_token(t)) for t in token_strs]
    await write_tokens(dut, token_values)
    await start_computation(dut)
    await wait_for_done(dut, max_cycles=25)
    
    result = int(dut.result.value)
    expected = 16 % 256
    if result != expected:
        raise TestFailure(f"Max tokens test failed: expected {expected}, got {result}")
    cocotb.log.info(f"  Result: {result} [PASS]")
    
    cocotb.log.info("\nAll boundary tests passed")