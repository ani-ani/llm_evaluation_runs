import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def ascii_to_bytes(s):
    """Convert ASCII string to list of bytes, padded to 8 chars with nulls."""
    result = [ord(c) for c in s]
    while len(result) < 8:
        result.append(0)
    return result[:8]  # Truncate if longer

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_string_concat(dut):
    """Test string concatenation module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.count.value = 0
    
    # Initialize all string arrays to null
    for i in range(8):
        dut.str0[i].value = 0
        dut.str1[i].value = 0
        dut.str2[i].value = 0
        dut.str3[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (str0, str1, str2, str3, count, expected_concatenated)
    test_cases = [
        ([], [], [], [], 0, ""),  # Empty
        (["a"], [], [], [], 1, "a"),  # Single char
        (["a", "b", "c"], [], [], [], 1, "abc"),  # One string
        (["x"], ["y"], [], [], 2, "xy"),  # Two strings
        (["a", "b", "c"], ["d", "e", "f"], [], [], 2, "abcdef"),  # Two strings with multiple chars
    ]
    
    test_num = 0
    passed = 0
    total = len(test_cases)
    
    for str0, str1, str2, str3, count, expected in test_cases:
        test_num += 1
        dut._log.info(f"Test {test_num}: Input strings: {str0}, {str1}, {str2}, {str3}, count={count}")
        
        # Convert strings to byte arrays
        bytes0 = ascii_to_bytes(''.join(str0))
        bytes1 = ascii_to_bytes(''.join(str1))
        bytes2 = ascii_to_bytes(''.join(str2))
        bytes3 = ascii_to_bytes(''.join(str3))
        
        # Load inputs
        for i in range(8):
            dut.str0[i].value = bytes0[i]
            dut.str1[i].value = bytes1[i]
            dut.str2[i].value = bytes2[i]
            dut.str3[i].value = bytes3[i]
        
        dut.count.value = count
        await RisingEdge(dut.clk)
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (36 cycles max)
        max_cycles = 40
        done_seen = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_seen = True
                # Verify result
                result_str = ""
                valid_output = True
                
                for i in range(32):
                    if not is_value_defined(dut.result[i].value):
                        dut._log.error(f"Result byte {i} is undefined")
                        valid_output = False
                        break
                    
                    byte_val = int(dut.result[i].value)
                    if byte_val != 0:
                        result_str += chr(byte_val)
                
                if not valid_output:
                    raise TestFailure(f"Test {test_num}: Result has undefined values")
                
                if result_str == expected:
                    dut._log.info(f"Test {test_num}: PASS - Got '{result_str}'")
                    passed += 1
                else:
                    raise TestFailure(f"Test {test_num}: Expected '{expected}', got '{result_str}'")
                
                break
        else:
            raise TestFailure(f"Test {test_num}: done signal not asserted after {max_cycles} cycles")
        
        # Brief gap between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")