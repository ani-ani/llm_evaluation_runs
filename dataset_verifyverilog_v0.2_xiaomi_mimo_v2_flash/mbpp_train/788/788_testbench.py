import cocotb
from cocotb.triggers import Timer
import random

def str_to_bytes(s):
    """Convert string to 8-element bytes array padded with spaces"""
    b = s.encode('ascii')
    padded = b + b' ' * (8 - len(b))
    return padded

def bytes_to_str(b):
    """Convert 8-element bytes array to string"""
    return b.decode('ascii').rstrip()

@cocotb.test()
async def test_new_tuple(dut):
    """Test new_tuple module with various inputs"""
    
    test_cases = [
        # (list_elements, append_str, expected_result)
        (["WEB", "is"], "best", ["WEB", "is", "best"]),
        (["We", "are"], "Developers", ["We", "are", "Developers"]),
        (["Part", "is"], "Wrong", ["Part", "is", "Wrong"]),
        (["A"], "B", ["A", "B"]),
        ([], "Solo", ["Solo"]),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (list_elems, append_str, expected) in enumerate(test_cases):
        # Prepare inputs
        list_length = len(list_elems)
        
        # Initialize list_data
        dut.list_data.value = 0
        for idx, elem in enumerate(list_elems):
            bytes_val = str_to_bytes(elem)
            for byte_idx in range(8):
                dut.list_data[idx].value = bytes_val[byte_idx]
        
        # Set append_str
        append_bytes = str_to_bytes(append_str)
        for byte_idx in range(8):
            dut.append_str[byte_idx].value = append_bytes[byte_idx]
        
        # Set list_length
        dut.list_length.value = list_length
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Verify results
        result_length = int(dut.result_length.value)
        
        # Check result_length
        if result_length != len(expected):
            print(f"Test {i+1} FAILED: Expected length {len(expected)}, got {result_length}")
            continue
        
        # Check each tuple element
        all_match = True
        result_list = []
        for idx in range(result_length):
            # Extract 8-byte string from result_tuple
            elem_bytes = bytes([int(dut.result_tuple[idx][b]) for b in range(8)])
            elem_str = bytes_to_str(elem_bytes)
            result_list.append(elem_str)
            if elem_str != expected[idx]:
                all_match = False
                print(f"Test {i+1} FAILED at index {idx}: Expected '{expected[idx]}', got '{elem_str}'")
        
        if all_match:
            print(f"Test {i+1} PASSED: {list_elems} + [{append_str}] = {result_list}")
            passed += 1
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"