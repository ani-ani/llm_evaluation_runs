import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import random

def string_to_bytes(s):
    """Convert string to 8-byte array with null padding"""
    result = [0] * 8
    for i, c in enumerate(s):
        if i < 8:
            result[i] = ord(c)
    return result

def bytes_to_string(bytes_list):
    """Convert 8-byte array to string stopping at null"""
    chars = []
    for b in bytes_list:
        if b == 0:
            break
        chars.append(chr(b))
    return ''.join(chars)

def python_sorted_list_sum(lst):
    """Python reference implementation"""
    # Filter even lengths
    filtered = [s for s in lst if len(s) % 2 == 0]
    # Sort by length then alphabetically
    filtered.sort(key=lambda x: (len(x), x))
    return filtered

@cocotb.test()
async def test_sorted_list_sum(dut):
    """Test sorted_list_sum module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_strings.value = 0
    for i in range(8):
        for j in range(8):
            dut.string_data[i][j].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (["aa", "a", "aaa"], ["aa"]),
        (["school", "AI", "asdf", "b"], ["AI", "asdf", "school"]),
        (["d", "b", "c", "a"], []),
        (["d", "dcba", "abcd", "a"], ["abcd", "dcba"]),
        (["AI", "ai", "au"], ["AI", "ai", "au"]),
        (["a", "b", "b", "c", "c", "a"], []),
        (["aaaa", "bbbb", "dd", "cc"], ["cc", "dd", "aaaa", "bbbb"]),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_idx, (input_list, expected_list) in enumerate(test_cases):
        # Setup inputs
        dut.num_strings.value = len(input_list)
        for i in range(8):
            if i < len(input_list):
                bytes_val = string_to_bytes(input_list[i])
                for j in range(8):
                    dut.string_data[i][j].value = bytes_val[j]
            else:
                for j in range(8):
                    dut.string_data[i][j].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 1000
        for _ in range(timeout):
            if dut.done.value:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Test {test_idx}: Timeout waiting for done")
        
        # Read results
        result_count = int(dut.result_count.value)
        result_strings = []
        for i in range(result_count):
            bytes_val = [int(dut.result_strings[i][j].value) for j in range(8)]
            result_strings.append(bytes_to_string(bytes_val))
        
        # Check
        if result_strings == expected_list:
            passed += 1
            print(f"Test {test_idx}: PASS - Input: {input_list}, Got: {result_strings}")
        else:
            print(f"Test {test_idx}: FAIL - Input: {input_list}, Expected: {expected_list}, Got: {result_strings}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")
