import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Helper function to convert ASCII string to array of bytes
def str_to_array(s):
    arr = [ord(c) for c in s]
    # Pad to 8 characters
    while len(arr) < 8:
        arr.append(0)
    return arr

# Helper to convert array back to string
def array_to_str(arr, length):
    return ''.join(chr(arr[i]) for i in range(length))

@cocotb.test()
async def test_reverse_words(dut):
    """Test word reversal with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.string_data.value = 0
    dut.string_length.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, expected_output_string, expected_length)
    test_cases = [
        ("python program", "program python", 13),
        ("java language", "language java", 12),
        ("man indian", "indian man", 10),
        ("a b c", "c b a", 5),
        ("hello", "hello", 5),
        ("ab cd ef", "ef cd ab", 8),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for input_str, expected_str, expected_len in test_cases:
        # Skip if input longer than 8 chars for this test
        if len(input_str) > 8:
            print(f"Skipping '{input_str}' - exceeds 8 char limit")
            total -= 1
            continue
        
        # Prepare input
        input_arr = str_to_array(input_str)
        input_len = len(input_str)
        
        dut.string_data.value = input_arr
        dut.string_length.value = input_len
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (with timeout)
        max_cycles = 20
        for _ in range(max_cycles):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Read result
        result_arr = [int(dut.result_data[i].value) for i in range(8)]
        result_len = int(dut.result_length.value)
        result_str = array_to_str(result_arr, result_len)
        
        # Verify
        if result_str == expected_str and result_len == expected_len:
            print(f"PASS: '{input_str}' -> '{result_str}'")
            passed += 1
        else:
            print(f"FAIL: '{input_str}' -> Expected '{expected_str}' (len={expected_len}), Got '{result_str}' (len={result_len})")
        
        await RisingEdge(dut.clk)
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
