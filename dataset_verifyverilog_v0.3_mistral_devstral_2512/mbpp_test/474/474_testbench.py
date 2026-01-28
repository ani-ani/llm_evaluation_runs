import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
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

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'valid_in'):
        dut.valid_in.value = 0
    if has_signal(dut, 'end_of_string'):
        dut.end_of_string.value = 0
    
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
# STRING PROCESSING HELPER
# ============================================================================

async def process_string(dut, input_string, target_char, replace_char):
    """Process a string through the DUT and return result."""
    result = []
    
    # Start the computation
    await start_computation(dut)
    
    # Feed characters one by one
    for i, char in enumerate(input_string):
        # Set current character and valid flag
        dut.char_in.value = ord(char)
        dut.valid_in.value = 1
        dut.end_of_string.value = 0
        
        # Set target and replacement characters
        dut.target_char.value = ord(target_char)
        dut.replace_char.value = ord(replace_char)
        
        await RisingEdge(dut.clk)
        
        # Read output if valid
        if is_value_defined(dut.valid_out.value) and int(dut.valid_out.value) == 1:
            if is_value_defined(dut.char_out.value):
                result.append(chr(int(dut.char_out.value)))
    
    # Signal end of string
    dut.valid_in.value = 0
    dut.end_of_string.value = 1
    await RisingEdge(dut.clk)
    
    # Wait for done
    await wait_for_done(dut)
    
    return ''.join(result)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_string_replace(dut):
    """Test character replacement in string."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_string, target_char, replace_char, expected_output, description)
    test_cases = [
        ("polygon", 'y', 'l', "pollgon", "Replace 'y' with 'l'"),
        ("character", 'c', 'a', "aharaater", "Replace 'c' with 'a'"),
        ("python", 'l', 'a', "python", "Replace 'l' with 'a' (no match)"),
        ("hello", 'h', 'H', "Hello", "Replace 'h' with 'H'"),
        ("aaaa", 'a', 'b', "bbbb", "Replace all characters"),
        ("test", 'x', 'y', "test", "No replacement needed"),
        ("", 'a', 'b', "", "Empty string"),
        ("a", 'a', 'b', "b", "Single character match"),
        ("a", 'b', 'c', "a", "Single character no match"),
        ("abac", 'a', 'z', "zbzc", "Multiple occurrences"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, target, replace, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: '{input_str}', Target: '{target}', Replace: '{replace}'")
        cocotb.log.info(f"  Expected: '{expected}'")
        
        try:
            # Reset for each test
            await reset_dut(dut)
            
            # Process the string
            result = await process_string(dut, input_str, target, replace)
            
            # Verify result
            if result != expected:
                raise TestFailure(f"Expected '{expected}', got '{result}'")
            
            cocotb.log.info(f"  Result: '{result}' [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    cocotb.log.info(f"{'='*60}")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")