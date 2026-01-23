import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
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

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'char_in'):
        dut.char_in.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def parse_tuple_string(dut, test_str):
    """Parse a tuple string and return the result array."""
    # Remove parentheses and extract numbers
    clean_str = test_str.replace('(', '').replace(')', '').replace('...', '')
    parts = clean_str.split(', ')
    expected_numbers = [int(p) for p in parts if p]
    
    # Extract actual string characters (excluding outer parentheses)
    # The test_str format is "(num1, num2, ...)"
    # We need to feed the inner characters to the module
    inner_str = test_str[1:-1]  # Remove outer ( and )
    char_list = [ord(c) for c in inner_str]
    char_len = len(char_list)
    
    # Calculate expected result
    expected_arr = [0] * 8
    for i, num in enumerate(expected_numbers):
        if i < 8:
            expected_arr[i] = num
    expected_len = min(len(expected_numbers), 8)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed characters one by one on each clock cycle
    for i in range(char_len):
        dut.char_in.value = char_list[i]
        await RisingEdge(dut.clk)
    
    # Wait for done
    cycles = 0
    while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
        await RisingEdge(dut.clk)
        cycles += 1
        if cycles > MAX_CYCLES:
            raise TestFailure(f"Timeout waiting for done signal")
    
    # Read results
    result_len = int(dut.result_len.value)
    result_arr = []
    for i in range(ARRAY_SIZE):
        if is_value_defined(dut.result_arr[i].value):
            result_arr.append(int(dut.result_arr[i].value))
        else:
            result_arr.append(0)
    
    error = int(dut.error.value) if is_value_defined(dut.error.value) else 0
    
    return result_arr, result_len, error, expected_arr, expected_len

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tuple_str_int(dut):
    """Test tuple string to integer tuple conversion."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        "(7, 8, 9)",
        "(1, 2, 3)",
        "(4, 5, 6)",
        "(7, 81, 19)",
    ]
    
    passed = 0
    failed = 0
    
    for i, test_str in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {test_str}")
        
        try:
            result_arr, result_len, error, expected_arr, expected_len = await parse_tuple_string(dut, test_str)
            
            if error:
                raise TestFailure(f"Error flag asserted during parsing")
            
            if result_len != expected_len:
                raise TestFailure(f"Length mismatch: expected {expected_len}, got {result_len}")
            
            # Check only the valid entries
            for idx in range(expected_len):
                if result_arr[idx] != expected_arr[idx]:
                    raise TestFailure(f"Position {idx}: expected {expected_arr[idx]}, got {result_arr[idx]}")
            
            cocotb.log.info(f"  PASS: {result_arr[:result_len]}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")