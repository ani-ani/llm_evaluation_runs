import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
STRING_LEN = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def write_string(dut, test_string):
    """Write string to char_array, truncate to 16 chars."""
    padded = test_string[:STRING_LEN]
    for i in range(STRING_LEN):
        if i < len(padded):
            dut.char_array[i].value = ord(padded[i])
        else:
            dut.char_array[i].value = 0
    dut.length.value = len(padded)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_text_lowercase_underscore(dut):
    """Test the text_lowercase_underscore module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_result, description)
    test_cases = [
        ("aab_cbbbc", True, "Valid: lowercase + underscore + lowercase"),
        ("aab_Abbbc", False, "Invalid: uppercase in second part"),
        ("Aaab_abbbc", False, "Invalid: uppercase in first part"),
        ("a_b", True, "Valid: minimal case"),
        ("ab_c", True, "Valid: short string"),
        ("a__b", False, "Invalid: double underscore"),
        ("_abc", False, "Invalid: starts with underscore"),
        ("abc_", False, "Invalid: ends with underscore"),
        ("abc", False, "Invalid: no underscore"),
        ("123_abc", False, "Invalid: digits in first part"),
        ("abc_123", False, "Invalid: digits in second part"),
        ("a_b_c", False, "Invalid: multiple underscores"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_str, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: '{test_str}'")
        
        try:
            # Write string to DUT
            await write_string(dut, test_str)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = bool(int(dut.result.value))
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
