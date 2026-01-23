import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_add_dict_to_tuple(dut):
    """Test appending dictionary values to a tuple."""
    
    # Helper function to convert list to fixed-width array inputs
    def set_inputs(tuple_list, dict_data):
        # Reset inputs
        for i in range(3):
            dut.tuple_data[i] = 0
            dut.dict_keys[i] = 0
            dut.dict_vals[i] = 0
        
        # Set Tuple inputs
        dut.tuple_len = len(tuple_list)
        for i, val in enumerate(tuple_list):
            dut.tuple_data[i] = val
        
        # Set Dictionary inputs
        # dict_data is a dict, we need to extract values
        dict_items = list(dict_data.items())
        dut.dict_len = len(dict_items)
        for i, (k, v) in enumerate(dict_items):
            # For simplicity in test, we treat keys as ASCII values if string, else ints
            # Assuming keys are strings in the test cases provided
            if isinstance(k, str):
                dut.dict_keys[i] = ord(k[0]) # Just take first char for 8-bit width
            else:
                dut.dict_keys[i] = k
            dut.dict_vals[i] = v

    # Test Case 1
    await Timer(1, units='ns')
    tuple1 = [4, 5, 6]
    dict1 = {'M': 1, 'S': 2, 'B': 3} # Shortened keys to fit 8-bit if needed, or we use ord
    # Note: The problem text uses strings "MSAM", "is", "best". Keys are strings.
    # We will map the keys to their ASCII sum or first char for 8-bit input.
    # Let's assume the logic is just to append the VALUES.
    
    set_inputs(tuple1, {'M': 1, 'S': 2, 'B': 3})
    await Timer(1, units='ns')
    
    # Expected result: Bytes 4, 5, 6, 1, 2, 3 packed into 64-bit
    # Layout: result[63:0] = {tuple[0], tuple[1], tuple[2], val1, val2, val3}...
    # Let's assume little-endian or just byte array.
    # Python: 4, 5, 6, 1, 2, 3 -> Hex 0x0000000000030201060504? No, that's confusing.
    # Let's assume result[7:0] = first element, result[15:8] = second, etc.
    
    expected1 = (4) | (5 << 8) | (6 << 16) | (1 << 24) | (2 << 32) | (3 << 40)
    # dut.result is 64 bits.
    assert dut.result.value == expected1, f"Test 1 Failed: Expected {expected1}, got {dut.result.value}
    
    # Test Case 2
    tuple2 = [1, 2, 3]
    dict2 = {'U': 2, 'I': 3, 'W': 4}
    set_inputs(tuple2, dict2)
    await Timer(1, units='ns')
    expected2 = (1) | (2 << 8) | (3 << 16) | (2 << 24) | (3 << 32) | (4 << 40)
    assert dut.result.value == expected2, f"Test 2 Failed: Expected {expected2}, got {dut.result.value}
    
    # Test Case 3
    tuple3 = [8, 9, 10]
    dict3 = {'P': 3, 'I': 4, 'O': 5}
    set_inputs(tuple3, dict3)
    await Timer(1, units='ns')
    expected3 = (8) | (9 << 8) | (10 << 16) | (3 << 24) | (4 << 32) | (5 << 40)
    assert dut.result.value == expected3, f"Test 3 Failed: Expected {expected3}, got {dut.result.value}
    
    # Edge Case: Empty Tuple, Full Dict
    set_inputs([], {'X': 99})
    await Timer(1, units='ns')
    expected_edge = 99
    assert dut.result.value == expected_edge, f"Edge Case Failed: Expected {expected_edge}, got {dut.result.value}
    
    print("All tests passed!")