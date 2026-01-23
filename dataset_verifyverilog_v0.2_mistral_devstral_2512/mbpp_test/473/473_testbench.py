import cocotb
from cocotb.triggers import Timer
import random

def python_implementation(test_list1, test_list2):
    res = set([tuple(sorted(ele)) for ele in test_list1]) & set([tuple(sorted(ele)) for ele in test_list2])
    return res

@cocotb.test()
async def test_tuple_intersection(dut):
    """Test tuple intersection with 4 tuples of 2 elements each"""
    
    # Test cases scaled to fit the adaptation:
    # List 1: [(3, 4), (5, 6), (9, 10), (4, 5)] -> Indices 0, 1, 2, 3
    # List 2: [(5, 4), (3, 4), (6, 5), (9, 11)] -> Indices 0, 1, 2, 3
    # Expected matches: (3,4) matches (3,4), (5,6) matches (6,5), (4,5) matches (5,4)
    # Result: {0, 1, 3} -> binary 1101 -> hex 0xD
    
    test_vectors = [
        # (list1_flat, list2_flat, expected_mask_desc)
        # Case 1: Matches at indices 0, 1, 3
        ([3, 4, 5, 6, 9, 10, 4, 5], [5, 4, 3, 4, 6, 5, 9, 11], 0b1101),
        # Case 2: [ (4,1), (7,4), (11,13), (17,14) ] vs [ (1,4), (7,4), (16,12), (10,13) ]
        # Matches: (4,1) with (1,4) -> idx 0. (7,4) with (7,4) -> idx 1. 
        # Note: (11,13) vs (10,13) fails. (17,14) vs (16,12) fails.
        # Python result: {(1,4), (4,7)} -> sorted (1,4) and (4,7).
        # In our input: (1,4) is index 0, (7,4) is index 1.
        # So indices {0, 1} -> mask 0b0011 -> hex 0x3
        ([4, 1, 7, 4, 11, 13, 17, 14], [1, 4, 7, 4, 16, 12, 10, 13], 0b0011),
        # Case 3: [ (2,1), (3,2), (1,3), (1,4) ] vs [ (11,2), (2,3), (6,2), (1,3) ]
        # Matches: (3,2) with (2,3) -> idx 1. (1,3) with (1,3) -> idx 2.
        # Python result: {(1,3), (2,3)}.
        # In our input: (3,2) is index 1, (1,3) is index 2.
        # So indices {1, 2} -> mask 0b0110 -> hex 0x6
        ([2, 1, 3, 2, 1, 3, 1, 4], [11, 2, 2, 3, 6, 2, 1, 3], 0b0110),
    ]

    for i, (l1_flat, l2_flat, expected_mask) in enumerate(test_vectors):
        dut._log.info(f"Running Test Case {i+1}: Mask expected {expected_mask:04b}")
        
        # Assign inputs from flattened list
        # List 1
        dut.in1_0.value = l1_flat[0]
        dut.in1_1.value = l1_flat[1]
        dut.in1_2.value = l1_flat[2]
        dut.in1_3.value = l1_flat[3]
        dut.in1_4.value = l1_flat[4]
        dut.in1_5.value = l1_flat[5]
        dut.in1_6.value = l1_flat[6]
        dut.in1_7.value = l1_flat[7]
        # List 2
        dut.in2_0.value = l2_flat[0]
        dut.in2_1.value = l2_flat[1]
        dut.in2_2.value = l2_flat[2]
        dut.in2_3.value = l2_flat[3]
        dut.in2_4.value = l2_flat[4]
        dut.in2_5.value = l2_flat[5]
        dut.in2_6.value = l2_flat[6]
        dut.in2_7.value = l2_flat[7]
        
        # Propagation delay for combinational logic
        await Timer(10, units='ns')
        
        # Read output
        actual_mask = int(dut.match_mask.value)
        
        assert actual_mask == expected_mask, f"Test {i+1} Failed: expected {expected_mask:04b}, got {actual_mask:04b}"

    print(f"All {len(test_vectors)} tests passed!")
