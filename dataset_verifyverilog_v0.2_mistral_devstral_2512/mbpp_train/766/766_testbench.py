import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_pairwise_consecutive(dut):
    """Test pairwise consecutive pairs generation"""
    
    # Initialize inputs
    dut.data_in.value = 0
    dut.num_elements.value = 0
    
    await Timer(10, units='ns')
    
    # Test 1: [1,1,2,3,3,4,4,5] -> 7 pairs
    dut._log.info("Test 1: [1,1,2,3,3,4,4,5]")
    dut.data_in.value = [1, 1, 2, 3, 3, 4, 4, 5]
    dut.num_elements.value = 8
    await Timer(10, units='ns')
    
    expected_pairs_1 = [(1, 1), (1, 2), (2, 3), (3, 3), (3, 4), (4, 4), (4, 5)]
    num_pairs_1 = dut.num_pairs.value
    assert num_pairs_1 == 7, f"Expected 7 pairs, got {num_pairs_1}"
    
    for i, (first, second) in enumerate(expected_pairs_1):
        actual_pair = dut.pairs_out.value[i]
        expected_pair = (first << 8) | second
        assert actual_pair == expected_pair, f"Pair {i}: expected {expected_pair}, got {actual_pair}"
    
    # Test 2: [1,5,7,9,10] -> 4 pairs
    dut._log.info("Test 2: [1,5,7,9,10]")
    dut.data_in.value = [1, 5, 7, 9, 10, 0, 0, 0]
    dut.num_elements.value = 5
    await Timer(10, units='ns')
    
    expected_pairs_2 = [(1, 5), (5, 7), (7, 9), (9, 10)]
    num_pairs_2 = dut.num_pairs.value
    assert num_pairs_2 == 4, f"Expected 4 pairs, got {num_pairs_2}"
    
    for i, (first, second) in enumerate(expected_pairs_2):
        actual_pair = dut.pairs_out.value[i]
        expected_pair = (first << 8) | second
        assert actual_pair == expected_pair, f"Pair {i}: expected {expected_pair}, got {actual_pair}"
    
    # Test 3: [5,1,9,7,10] -> 4 pairs
    dut._log.info("Test 3: [5,1,9,7,10]")
    dut.data_in.value = [5, 1, 9, 7, 10, 0, 0, 0]
    dut.num_elements.value = 5
    await Timer(10, units='ns')
    
    expected_pairs_3 = [(5, 1), (1, 9), (9, 7), (7, 10)]
    num_pairs_3 = dut.num_pairs.value
    assert num_pairs_3 == 4, f"Expected 4 pairs, got {num_pairs_3}"
    
    for i, (first, second) in enumerate(expected_pairs_3):
        actual_pair = dut.pairs_out.value[i]
        expected_pair = (first << 8) | second
        assert actual_pair == expected_pair, f"Pair {i}: expected {expected_pair}, got {actual_pair}"
    
    # Test 4: [1,2,3,4,5,6,7,8] -> 7 pairs (full array)
    dut._log.info("Test 4: [1,2,3,4,5,6,7,8]")
    dut.data_in.value = [1, 2, 3, 4, 5, 6, 7, 8]
    dut.num_elements.value = 8
    await Timer(10, units='ns')
    
    expected_pairs_4 = [(1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 8)]
    num_pairs_4 = dut.num_pairs.value
    assert num_pairs_4 == 7, f"Expected 7 pairs, got {num_pairs_4}"
    
    for i, (first, second) in enumerate(expected_pairs_4):
        actual_pair = dut.pairs_out.value[i]
        expected_pair = (first << 8) | second
        assert actual_pair == expected_pair, f"Pair {i}: expected {expected_pair}, got {actual_pair}"
    
    # Test 5: Edge case - single element
    dut._log.info("Test 5: [42] (single element)")
    dut.data_in.value = [42, 0, 0, 0, 0, 0, 0, 0]
    dut.num_elements.value = 1
    await Timer(10, units='ns')
    
    num_pairs_5 = dut.num_pairs.value
    assert num_pairs_5 == 0, f"Expected 0 pairs for single element, got {num_pairs_5}"
    
    # Test 6: Edge case - two elements
    dut._log.info("Test 6: [99, 100] (two elements)")
    dut.data_in.value = [99, 100, 0, 0, 0, 0, 0, 0]
    dut.num_elements.value = 2
    await Timer(10, units='ns')
    
    num_pairs_6 = dut.num_pairs.value
    assert num_pairs_6 == 1, f"Expected 1 pair for two elements, got {num_pairs_6}"
    actual_pair_6 = dut.pairs_out.value[0]
    expected_pair_6 = (99 << 8) | 100
    assert actual_pair_6 == expected_pair_6, f"Pair 0: expected {expected_pair_6}, got {actual_pair_6}"
    
    dut._log.info("All tests passed!")