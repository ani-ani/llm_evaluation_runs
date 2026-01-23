import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper function to check if a value is defined (not X or Z)
def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper function to pack string into char array
def pack_string(s, length=16):
    """Pack a string into array values, pad with spaces."""
    if len(s) > length:
        s = s[:length]
    s = s.ljust(length, ' ')
    return [ord(c) for c in s]

async def wait_for_done(dut, max_cycles=100):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_parse_nested_parens(dut):
    """Test parse_nested_parens module with various test cases."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut._log.info("Applying reset...")
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, expected_depth)
    test_cases = [
        ("(()()) ((())) () ((())()())", 3),
        ("() (()) ((())) (((())))", 4),
        ("(()(())((())))", 4),
        ("()", 1),
        ("", 0),
        ("((((()))))", 5),
        ("(()())()", 2),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_str, expected) in enumerate(test_cases):
        dut._log.info(f"\nTest case {i+1}: '{input_str}' -> expected {expected}")
        
        # Pack string into array
        char_values = pack_string(input_str, 16)
        
        # Assign to dut array (element by element)
        for idx, val in enumerate(char_values):
            dut.char_array[idx].value = val
        
        dut._log.info(f"Packed string: {''.join(chr(c) for c in char_values)}")
        dut._log.info(f"Array values: {char_values}")
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, max_cycles=20)
        
        # Check output validity
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        if result == expected:
            dut._log.info(f"Test {i+1}: PASSED - Got {result}")
            passed += 1
        else:
            raise TestFailure(f"Test {i+1}: FAILED - Expected {expected}, got {result}")
        
        # Wait for idle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")
    dut._log.info(f"{'='*50}")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
