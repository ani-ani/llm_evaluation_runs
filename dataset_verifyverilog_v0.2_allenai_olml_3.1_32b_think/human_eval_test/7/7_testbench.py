import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

def string_to_bits(s: str, length=8) -> int:
    """Convert string to 64-bit representation (8 chars × 8 bits)"""
    padded = s.ljust(length, '\0')
    result = 0
    for i, ch in enumerate(padded[:length]):
        result |= ord(ch) << (i * 8)
    return result

def bits_to_string(bits: int, length=8) -> str:
    """Convert 64-bit representation back to string"""
    chars = []
    for i in range(length):
        char_code = (bits >> (i * 8)) & 0xFF
        if char_code == 0:
            break
        chars.append(chr(char_code))
    return ''.join(chars)

@cocotb.test()
async def test_filter_by_substring(dut):
    """Test filter_by_substring module with various cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.substring.value = 0
    dut.valid_count.value = 0
    for i in range(8):
        dut.input_strings[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (input_strings, substring, expected_matching_indices)
        ([], 'a', []),
        (['abc', 'bacd', 'cde', 'array'], 'a', [0, 1, 3]),  # Indices of matches
        (['xxx', 'asd', 'xxy', 'john doe', 'xxxAAA', 'xxx'], 'xxx', [0, 4, 5]),
        (['xxx', 'asd', 'aaaxxy', 'john doe', 'xxxAAA', 'xxx'], 'xx', [0, 2, 4, 5]),
        (['grunt', 'trumpet', 'prune', 'gruesome'], 'run', [0, 2]),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (strings, substr, expected_indices) in enumerate(test_cases):
        dut._log.info(f"Test case {idx+1}: strings={strings}, substring='{substr}'")
        
        # Prepare inputs
        dut.valid_count.value = len(strings)
        for i in range(8):
            if i < len(strings):
                dut.input_strings[i].value = string_to_bits(strings[i])
            else:
                dut.input_strings[i].value = 0
        
        dut.substring.value = string_to_bits(substr)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 1000
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout == 0:
            dut._log.error(f"Test {idx+1}: Timeout waiting for done")
            continue
        
        # Read results
        match_count = int(dut.match_count.value)
        match_indices = []
        for i in range(match_count):
            match_indices.append(int(dut.match_indices[i].value))
        
        # Sort both for comparison (order may vary)
        match_indices.sort()
        expected_indices.sort()
        
        if match_indices == expected_indices and match_count == len(expected_indices):
            dut._log.info(f"Test {idx+1}: PASS")
            passed += 1
        else:
            dut._log.error(f"Test {idx+1}: FAIL - Expected {expected_indices}, got {match_indices}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
Results: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
