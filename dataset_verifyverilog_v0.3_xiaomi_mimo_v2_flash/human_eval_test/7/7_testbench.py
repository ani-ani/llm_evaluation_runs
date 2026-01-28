import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper function to check if value is defined (not X or Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper function to convert string to fixed-width array (8 chars)
def str_to_bytes(s, width=8):
    """Convert Python string to list of byte values (zero-padded)"""
    bytes_list = [ord(c) for c in s[:width]]
    # Pad with zeros
    while len(bytes_list) < width:
        bytes_list.append(0)
    return bytes_list

# Helper to pack bytes into a single value for packed array interface
def pack_bytes(bytes_list):
    """Pack list of bytes into integer (little-endian: byte0 at bit 0)"""
    result = 0
    for i, b in enumerate(bytes_list):
        result |= (b << (8 * i))
    return result

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_filter_by_substring(dut):
    """Test filter_by_substring module with various cases"""
    
    dut._log.info("Starting filter_by_substring tests")
    
    # Test case format: (strings_list, substring_str, expected_mask)
    test_cases = [
        # Empty strings list -> mask should be 0
        (["", "", "", ""], "a", 0),
        
        # Original test case 1: filter ['abc', 'bacd', 'cde', 'array'] for 'a'
        (["abc", "bacd", "cde", "array"], "a", 0b1101),  # indices 0,1,3 have 'a'
        
        # Original test case 2: ['xxx', 'asd', 'xxy', 'john doe'] for 'xxx'
        # With 4-string limit, truncated: ['xxx', 'asd', 'xxy', 'john doe']
        # 'xxx' matches string 0, 'asd' no, 'xxy' no (has 'xx' but not 'xxx'), 'john doe' no
        (["xxx", "asd", "xxy", "john doe"], "xxx", 0b0001),
        
        # Original test case 3: ['xxx', 'asd', 'aaaxxy', 'john doe'] for 'xx'
        # 'xxx' yes, 'asd' no, 'aaaxxy' yes, 'john doe' no
        (["xxx", "asd", "aaaxxy", "john doe"], "xx", 0b0101),  # indices 0,2
        
        # Original test case 4: ['grunt', 'trumpet', 'prune', 'gruesome'] for 'run'
        # 'grunt' yes, 'trumpet' no (wait, 'trumpet' contains 'ru', not 'run')
        # 'prune' yes (contains 'run'? p-r-u-n-e... no 'r' followed by 'u' followed by 'n'? 
        # 'prune' has 'run' substring? p-r-u-n-e: positions 1-3 are r-u-n -> YES!
        # 'gruesome' has 'ru' but not 'run'
        (["grunt", "trumpet", "prune", "gruesome"], "run", 0b1010),  # indices 0,2
        
        # Additional edge cases
        # Substring longer than string
        (["ab", "abc", "abcd", "abcde"], "abcdef", 0b0000),
        
        # Empty substring
        (["abc", "def", "ghi", "jkl"], "", 0b0000),
        
        # Match at end of string
        (["0000xyz", "xyz", "abxyz", "no"], "xyz", 0b0111),  # 0,1,2
        
        # All strings match
        (["aaa", "aaa", "aaa", "aaa"], "aaa", 0b1111),
        
        # No strings match
        (["xyz", "xyz", "xyz", "xyz"], "abc", 0b0000),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (strings_list, substring_str, expected_mask) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}/{total}: substring='{substring_str}' in strings={strings_list}")
        
        # Prepare strings (4 strings, 8 chars each)
        for s_idx in range(4):
            s = strings_list[s_idx] if s_idx < len(strings_list) else ""
            bytes_list = str_to_bytes(s, width=8)
            dut._log.info(f"  String {s_idx}: '{s}' -> bytes {bytes_list}")
            
            # Assign to Verilog array
            for char_idx in range(8):
                dut.strings[s_idx][char_idx].value = bytes_list[char_idx]
        
        # Prepare substring (up to 4 chars)
        sub_bytes = str_to_bytes(substring_str, width=4)
        sub_len = min(len(substring_str), 4)
        dut._log.info(f"  Substring: '{substring_str}' (len={sub_len}) -> bytes {sub_bytes}")
        
        for char_idx in range(4):
            dut.substring[char_idx].value = sub_bytes[char_idx]
        dut.substring_len.value = sub_len
        
        # Wait for combinational logic to propagate
        await Timer(100, units='ns')
        
        # Read result
        if not is_value_defined(dut.mask.value):
            raise TestFailure(f"Test {i+1}: mask output is undefined (X/Z)")
        
        result_mask = int(dut.mask.value)
        
        if result_mask != expected_mask:
            # Provide detailed diagnostic
            result_str = f"{result_mask:04b}"
            expected_str = f"{expected_mask:04b}"
            raise TestFailure(
                f"Test {i+1} FAILED:\n"
                f"  Substring: '{substring_str}'\n"
                f"  Strings: {strings_list}\n"
                f"  Expected mask: {expected_str} (0b{expected_str})\n"
                f"  Got mask:      {result_str} (0b{result_str})\n"
                f"  Differences:\n"
                f"    Expected bits: {[j for j in range(4) if (expected_mask >> j) & 1]}\n"
                f"    Got bits:       {[j for j in range(4) if (result_mask >> j) & 1]}"
            )
        
        dut._log.info(f"  Result mask: {result_mask:04b} [OK]")
        passed += 1
    
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")
    dut._log.info(f"{'='*50}")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
