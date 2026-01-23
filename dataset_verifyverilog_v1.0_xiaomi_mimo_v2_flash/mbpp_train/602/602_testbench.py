import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_string_to_ports(dut, test_string):
    """Write string characters to individual char_0..char_15 ports."""
    # Ensure string length doesn't exceed 16
    if len(test_string) > 16:
        test_string = test_string[:16]
    
    # Write each character to its port
    for i in range(16):
        port_name = f'char_{i}'
        if has_signal(dut, port_name):
            if i < len(test_string):
                char_val = ord(test_string[i])
                getattr(dut, port_name).value = clamp_to_width(char_val, DATA_WIDTH)
            else:
                getattr(dut, port_name).value = 0
        else:
            raise TestFailure(f"Port {port_name} not found")
    
    # Set string length
    if has_signal(dut, 'str_len'):
        dut.str_len.value = len(test_string)
    else:
        raise TestFailure("Port 'str_len' not found")

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

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
async def test_first_repeated_char(dut):
    """Test first_repeated_char module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_char_or_none, description)
    test_cases = [
        ("abcabc", "a", "Test 1: abcabc -> a"),
        ("abc", None, "Test 2: abc -> None"),
        ("123123", "1", "Test 3: 123123 -> 1"),
        ("abca", "a", "Test 4: abca -> a"),
        ("", None, "Test 5: empty string -> None"),
        ("a", None, "Test 6: single char -> None"),
        ("aa", "a", "Test 7: aa -> a"),
        ("abcdefghij", None, "Test 8: all unique -> None"),
        ("abcdefghia", "a", "Test 9: repeat at end -> a"),
        ("abcdefga", "a", "Test 10: repeat at start -> a"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_str, expected_char, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write string to DUT
            await write_string_to_ports(dut, test_str)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result_valid.value):
                raise TestFailure("result_valid is undefined (X/Z)")
            
            result_valid = int(dut.result_valid.value)
            result_char = int(dut.result_char.value)
            
            # Convert expected to ASCII value
            if expected_char is None:
                expected_valid = 0
                expected_char_val = 0
            else:
                expected_valid = 1
                expected_char_val = ord(expected_char)
            
            # Check results
            if result_valid != expected_valid:
                raise TestFailure(
                    f"result_valid mismatch: expected {expected_valid}, got {result_valid}"
                )
            
            if result_valid and result_char != expected_char_val:
                expected_str = chr(expected_char_val)
                actual_str = chr(result_char) if result_char >= 32 else f"(0x{result_char:02X})"
                raise TestFailure(
                    f"result_char mismatch: expected '{expected_str}', got '{actual_str}'"
                )
            
            cocotb.log.info(f"  PASS: result_valid={result_valid}, result_char={result_char}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Wait one cycle before next test
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")