import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

# Helper function to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to convert string to byte array for Verilog
def str_to_bytes(s, length=16):
    # Pad with spaces (0x20) to fill length
    bytes_list = [ord(c) for c in s]
    if len(bytes_list) < length:
        bytes_list.extend([0x20] * (length - len(bytes_list)))
    elif len(bytes_list) > length:
        bytes_list = bytes_list[:length]
    return bytes_list

# Helper to convert byte array back to string for verification
def bytes_to_str(bytes_list):
    # Trim trailing spaces and nulls
    s = ''.join(chr(b) for b in bytes_list)
    return s.rstrip(' \x00')

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_word_selector(dut):
    """Test the word selector module."""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (string, n, expected_word)
    test_cases = [
        ("Mary had a little lamb", 4, "little"),
        ("Mary had a little lamb", 3, "Mary"),  # Should pick first match
        ("simple white space", 2, ""),          # Empty
        ("Hello world", 4, "world"),
        ("Uncle sam", 3, "Uncle"),
        ("", 4, ""),                           # Empty string
        ("a b c d e f", 1, "b"),               # Pick first matching single char word
        ("test best", 3, "test"),               # Both have 3 consonants, pick first
    ]
    
    passed = 0
    total = len(test_cases)
    
    for s, n, expected in test_cases:
        # Prepare Input
        byte_array = str_to_bytes(s, length=16)
        
        # Assign Input Array (Element by Element)
        for i in range(16):
            dut.str[i].value = byte_array[i]
        
        dut.n.value = n
        
        # Start Pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with timeout logic
        done_found = False
        max_cycles = 100
        
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            dut._log.error(f"Test '{s}' timed out waiting for done")
            continue
            
        # Read Output Array
        if not is_value_defined(dut.result[0].value):
             dut._log.error(f"Test '{s}' result has X/Z values")
             continue
             
        output_bytes = [int(dut.result[i].value) for i in range(16)]
        result_str = bytes_to_str(output_bytes)
        
        # Verify
        if result_str == expected:
            passed += 1
            dut._log.info(f"Test passed: '{s}' -> '{result_str}'")
        else:
            dut._log.error(f"Test failed: '{s}' -> Expected '{expected}', got '{result_str}'")
            
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"