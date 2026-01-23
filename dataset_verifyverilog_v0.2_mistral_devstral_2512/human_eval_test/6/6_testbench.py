import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

def encode_paren_string(s):
    """Convert string to list of ASCII values, 0-terminated"""
    return [ord(c) for c in s] + [0]

@cocotb.test()
async def test_parse_nested_parens(dut):
    """Test parse_nested_parens module with various nested parenthesis strings"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid.value = 0
    dut.done_in.value = 0
    dut.char_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, expected_max_depth, expected_group_count)
    test_cases = [
        ('(()()) ((())) () ((())()())', [2, 3, 1, 3], 4),
        ('() (()) ((())) (((())))', [1, 2, 3, 4], 4),
        ('(()(())((())))', [4], 1),
    ]
    
    for test_num, (input_str, expected_depths, expected_groups) in enumerate(test_cases):
        print(f"
Test {test_num + 1}: {input_str}")
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed characters one per cycle
        char_list = encode_paren_string(input_str)
        for i, char in enumerate(char_list):
            dut.valid.value = 1
            dut.char_in.value = char
            dut.done_in.value = 1 if char == 0 else 0
            await RisingEdge(dut.clk)
            if char == 0:
                break
        
        # Wait for completion
        timeout = 100
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check results
        actual_groups = int(dut.group_count.value)
        actual_result = int(dut.result.value)
        
        print(f"  Expected: max_depth={max(expected_depths)}, groups={expected_groups}")
        print(f"  Got: max_depth={actual_result}, groups={actual_groups}")
        
        assert actual_groups == expected_groups, f"Group count mismatch: expected {expected_groups}, got {actual_groups}"
        assert actual_result == max(expected_depths), f"Max depth mismatch: expected {max(expected_depths)}, got {actual_result}"
    
    print("
All tests passed!")
    print(f"Summary: 3/3 tests passed")
