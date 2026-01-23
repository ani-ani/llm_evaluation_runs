import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper function to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper function to wait for done signal with timeout
def wait_for_done_with_timeout(dut, max_cycles):
    """Generator to wait for done signal with cycle timeout."""
    for cycle in range(max_cycles):
        yield RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return
    raise TestFailure(f"Timeout: done signal not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_is_nested(dut):
    """Test the is_nested module with various bracket strings."""
    
    # Start the clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.str_len.value = 0
    for i in range(16):
        dut.str[i].value = 0
    
    # Wait for 2 clock cycles with reset active
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    # Release reset
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases (string, expected_result)
    # Characters: '[' = 91 (0x5B), ']' = 93 (0x5D)
    test_cases = [
        ("[[]]", True),           # Nested
        ("[]]]]]]][[[[[]", False), # Not nested (invalid, but our simplified logic treats ']' at depth 0 as skip)
        ("[][]", False),          # Not nested
        ("[]", False),            # Not nested
        ("[[][]]", True),         # Nested
        ("[[]][[", True),         # Nested
        ("[[[[]]]]", True),       # Nested
        ("[]]]]]]]]]]", False),   # Not nested
        ("[][][[]]", True),       # Nested
        ("[]", False),            # Valid, not nested
        ("[[]", False),           # Invalid/Incomplete, not nested in our simple model
        ("[]]", False),           # Invalid/Extra close, not nested
        ("", False),              # Empty string
        ("[[[[[[[[", False),       # Not nested (only opens)
        (")))))))))", False),      # Invalid characters (should be ignored or handled gracefully)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (test_str, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: Input='{test_str}', Expected={expected}")
        
        # Setup input array
        str_len = len(test_str)
        dut.str_len.value = str_len
        
        # Fill the array (16 elements)
        for j in range(16):
            if j < str_len:
                char_code = ord(test_str[j])
                dut.str[j].value = char_code
            else:
                dut.str[j].value = 0
        
        # Start the computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        max_cycles = str_len + 10
        done_found = False
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined (X/Z)")
        
        actual = bool(int(dut.result.value))
        
        if actual == expected:
            dut._log.info(f"Test {i+1}: PASSED (Result={actual})")
            passed += 1
        else:
            raise TestFailure(f"Test {i+1}: FAILED. Expected {expected}, got {actual}")
    
    dut._log.info(f"\nSUMMARY: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Some tests failed ({passed}/{total})")