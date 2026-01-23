import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_max_length_finder(dut):
    """Test the max_length_finder combinational module"""
    
    # Helper to convert python list to flattened logic values
    def pack_list(data, length):
        # data is list of ints (0-255)
        # Return a flattened array for the dut input
        # The input is [3:0][7:0][7:0], so 4 lists of 8 bytes
        # We fill with 0 for padding
        packed = []
        for i in range(8):
            if i < length:
                packed.append(data[i])
            else:
                packed.append(0)
        return packed

    print("
Starting tests for max_length_finder")
    
    test_cases = [
        # (lists_data, lengths, expected_len, expected_list_index)
        # Adapted to 4 lists max
        # Test 1: [0], [1,3], [5,7], [9,11] -> max length 2 at index 2 or 3? 
        # Original: [[0], [1,3], [5,7], [9,11], [13,15,17]] -> 3 at index 4.
        # Scaled: We only have 4 lists. Let's use lists: [0], [1,3], [5,7], [13,15,17].
        # Lengths: 1, 2, 2, 3. Max=3. Index 3.
        ([ [0], [1,3], [5,7], [13,15,17] ], [1, 2, 2, 3], 3, 3),
        
        # Test 2: [[1], [5,7], [10,12,14,15]] -> adapted to 4 lists
        # Lists: [1], [5,7], [10,12,14,15], []
        # Lengths: 1, 2, 4, 0. Max=4. Index 2.
        ([ [1], [5,7], [10,12,14,15], [] ], [1, 2, 4, 0], 4, 2),

        # Test 3: [[5], [15,20,25]] -> adapted
        # Lists: [5], [15,20,25], [], []
        # Lengths: 1, 3, 0, 0. Max=3. Index 1.
        ([ [5], [15,20,25], [], [] ], [1, 3, 0, 0], 3, 1),

        # Test 4: Tie case
        # Lists: [1,2], [5,6], [10], []
        # Lengths: 2, 2, 1, 0. Max=2. Tie -> Index 0 (lowest).
        ([ [1,2], [5,6], [10], [] ], [2, 2, 1, 0], 2, 0),

        # Test 5: Empty case
        # Lists: [], [], [], []
        # Lengths: 0, 0, 0, 0. Max=0. Valid=0.
        ([ [], [], [], [] ], [0, 0, 0, 0], 0, 0),
    ]

    passed = 0
    total = len(test_cases)

    for i, (lists, lengths, exp_len, exp_idx) in enumerate(test_cases):
        # Setup inputs
        # Flatten for Verilog [3:0][7:0][7:0] 
        # In cocotb, for unpacked arrays, we might need to access dut.lists[i][j]
        # Let's assume the simulator handles the unpacked array access properly.
        
        # Set lengths
        dut.lengths[0] = lengths[0]
        dut.lengths[1] = lengths[1]
        dut.lengths[2] = lengths[2]
        dut.lengths[3] = lengths[3]
        
        # Set list data
        for list_idx in range(4):
            data = lists[list_idx]
            for elem_idx in range(8):
                if elem_idx < len(data):
                    dut.lists[list_idx][elem_idx] = data[elem_idx]
                else:
                    dut.lists[list_idx][elem_idx] = 0
        
        # Wait for combinational propagation
        await Timer(1, units='ns')
        
        # Read outputs
        out_len = int(dut.max_length.value)
        out_valid = int(dut.valid.value)
        
        # Read max_list
        # We need to know which list was selected to compare output
        # The module outputs the full 8-element vector of the selected list
        
        expected_list_data = [0]*8
        if exp_len > 0:
            expected_list_data = lists[exp_idx]
            # Pad with zeros to length 8
            expected_list_data = expected_list_data + [0]*(8 - len(expected_list_data))
        
        actual_list_data = []
        for k in range(8):
            actual_list_data.append(int(dut.max_list[k].value))
            
        # Assertions
        try:
            assert out_len == exp_len, f"Test {i+1} failed: Expected length {exp_len}, got {out_len}"
            
            exp_valid = 1 if exp_len > 0 else 0
            assert out_valid == exp_valid, f"Test {i+1} failed: Expected valid {exp_valid}, got {out_valid}"
            
            if exp_valid:
                assert actual_list_data == expected_list_data, f"Test {i+1} failed: Expected list {expected_list_data}, got {actual_list_data}"
            
            print(f"Test {i+1} Passed: Len={out_len}, List={actual_list_data[:exp_len]}")
            passed += 1
        except AssertionError as e:
            print(f"Test {i+1} Failed: {e}")

    print(f"
Result: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"