import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_tuple_length_checker(dut):
    """Test if tuple lengths are equal"""
    
    # Test Case 1: [(11, 22, 33), (44, 55, 66)] -> lengths [3, 3] -> True
    dut.valid_tuples_count.value = 2
    dut.tuple_lengths[0].value = 3
    dut.tuple_lengths[1].value = 3
    await Timer(1, units='ns')
    assert dut.equal.value == 1, f"Test 1 Failed: Expected 1, got {dut.equal.value}"
    print("Test 1 Passed: [(11, 22, 33), (44, 55, 66)]")

    # Test Case 2: [(1, 2, 3), (4, 5, 6, 7)] -> lengths [3, 4] -> False
    dut.valid_tuples_count.value = 2
    dut.tuple_lengths[0].value = 3
    dut.tuple_lengths[1].value = 4
    await Timer(1, units='ns')
    assert dut.equal.value == 0, f"Test 2 Failed: Expected 0, got {dut.equal.value}"
    print("Test 2 Passed: [(1, 2, 3), (4, 5, 6, 7)]")

    # Test Case 3: [(1, 2), (3, 4)] -> lengths [2, 2] -> True
    dut.valid_tuples_count.value = 2
    dut.tuple_lengths[0].value = 2
    dut.tuple_lengths[1].value = 2
    await Timer(1, units='ns')
    assert dut.equal.value == 1, f"Test 3 Failed: Expected 1, got {dut.equal.value}"
    print("Test 3 Passed: [(1, 2), (3, 4)]")

    # Edge Case 1: Single tuple (should be True)
    dut.valid_tuples_count.value = 1
    dut.tuple_lengths[0].value = 5
    await Timer(1, units='ns')
    assert dut.equal.value == 1, f"Edge Case 1 Failed: Expected 1, got {dut.equal.value}"
    print("Edge Case 1 Passed: Single tuple")

    # Edge Case 2: All 4 tuples have same length
    dut.valid_tuples_count.value = 4
    dut.tuple_lengths[0].value = 2
    dut.tuple_lengths[1].value = 2
    dut.tuple_lengths[2].value = 2
    dut.tuple_lengths[3].value = 2
    await Timer(1, units='ns')
    assert dut.equal.value == 1, f"Edge Case 2 Failed: Expected 1, got {dut.equal.value}"
    print("Edge Case 2 Passed: All 4 tuples same length")

    # Edge Case 3: Difference at index 3
    dut.valid_tuples_count.value = 4
    dut.tuple_lengths[0].value = 2
    dut.tuple_lengths[1].value = 2
    dut.tuple_lengths[2].value = 2
    dut.tuple_lengths[3].value = 3
    await Timer(1, units='ns')
    assert dut.equal.value == 0, f"Edge Case 3 Failed: Expected 0, got {dut.equal.value}"
    print("Edge Case 3 Passed: Difference at index 3")

    total = 6
    passed = 6
    print(f"
Summary: {passed}/{total} tests passed")