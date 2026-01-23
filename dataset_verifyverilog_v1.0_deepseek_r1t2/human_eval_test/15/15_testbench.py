import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper function to check if a value is defined (not X or Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to convert integer to ASCII character
def to_ascii(num):
    return 0x30 + num

@cocotb.test(timeout_time=2, timeout_unit='ms')
async def test_string_sequence(dut):
    """Test the string_sequence module with various inputs."""
    
    # Create a clock with 10ns period
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_n, expected_output_string)
    test_cases = [
        (0, '0'),
        (3, '0 1 2 3'),
        (7, '0 1 2 3 4 5 6 7'),
    ]
    
    total_tests = len(test_cases)
    passed_tests = 0
    
    for test_idx, (n_val, expected) in enumerate(test_cases):
        dut._log.info(f"Test {test_idx + 1}: n={n_val}, expecting '{expected}'")
        
        # Set input
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect output characters
        output_chars = []
        max_cycles = 50  # Safety limit
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            # Check if output is valid
            if is_value_defined(dut.valid.value) and dut.valid.value == 1:
                if is_value_defined(dut.byte_out.value):
                    char_code = int(dut.byte_out.value)
                    output_chars.append(chr(char_code))
                else:
                    raise TestFailure(f"Test {test_idx + 1}: byte_out is undefined at cycle {cycle}")
            
            # Check if done signal is asserted
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Test {test_idx + 1}: Done not asserted within {max_cycles} cycles")
        
        # Construct actual output string
        actual = ''.join(output_chars)
        
        dut._log.info(f"Test {test_idx + 1}: Got '{actual}'")
        
        if actual == expected:
            passed_tests += 1
            dut._log.info(f"Test {test_idx + 1} [PASSED]")
        else:
            raise TestFailure(f"Test {test_idx + 1}: Expected '{expected}', got '{actual}'")
        
        # Wait a bit before next test
        await Timer(100, units='ns')
    
    dut._log.info(f"\nSummary: {passed_tests}/{total_tests} tests passed")
    if passed_tests == total_tests:
        dut._log.info("All tests PASSED!")
    else:
        raise TestFailure(f"Only {passed_tests}/{total_tests} tests passed")