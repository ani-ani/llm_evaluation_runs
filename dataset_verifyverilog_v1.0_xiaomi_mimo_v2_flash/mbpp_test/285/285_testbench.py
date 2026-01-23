import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 16
MAX_CYCLES = 50
CLK_PERIOD_NS = 10

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
# ARRAY WRITE/READ HELPERS
# ============================================================================

async def write_string_array(dut, test_string):
    """Write string to array, handling individual element assignment."""
    # Pad to 16 characters with null terminators
    padded = (test_string + '\x00' * 16)[:16]
    
    for i in range(16):
        # Try indexed array first
        try:
            dut.str[i].value = ord(padded[i])
        except (AttributeError, TypeError):
            # Try individual ports
            port_name = f'str_{i}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = ord(padded[i])
            else:
                raise TestFailure(f"Cannot find array port for index {i}")

async def set_valid_len(dut, length):
    """Set the valid_len signal."""
    if has_signal(dut, 'valid_len'):
        dut.valid_len.value = clamp_to_width(length, 4)
    else:
        raise TestFailure("Signal 'valid_len' not found")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pattern_matcher(dut):
    """Test the pattern matcher with various strings."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_result, description)
    test_cases = [
        ("ac", False, "Test 1: 'ac' - no pattern"),
        ("dc", False, "Test 2: 'dc' - no pattern"),
        ("abbbba", True, "Test 3: 'abbbba' - contains 'abbb'"),
        ("abb", True, "Additional: 'abb' - exact match"),
        ("abbb", True, "Additional: 'abbb' - exact match"),
        ("ab", False, "Additional: 'ab' - too short"),
        ("abbbb", False, "Additional: 'abbbb' - too long"),
        ("a", False, "Additional: 'a' - no b's"),
        ("b", False, "Additional: 'b' - no a"),
        ("xabbb", True, "Additional: 'xabbb' - prefix"),
        ("abbx", False, "Additional: 'abbx' - wrong suffix"),
        ("aaabbb", False, "Additional: 'aaabbb' - multiple a's"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_string, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write string to array
            await write_string_array(dut, test_string)
            
            # Set valid length
            await set_valid_len(dut, len(test_string))
            
            # Wait a cycle for inputs to stabilize
            await RisingEdge(dut.clk)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            expected_int = 1 if expected else 0
            
            if result != expected_int:
                raise TestFailure(f"Expected {expected_int} ({expected}), got {result}")
            
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