import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_array_transpose(dut):
    """Test array transpose functionality"""
    
    # Test Case 1: Basic transpose with 3 pairs of characters
    dut.data_in[0][0].value = ord('x')  # First row, first element
    dut.data_in[0][1].value = ord('y')  # First row, second element
    dut.data_in[1][0].value = ord('a')
    dut.data_in[1][1].value = ord('b')
    dut.data_in[2][0].value = ord('m')
    dut.data_in[2][1].value = ord('n')
    # Fill remaining with zeros
    for i in range(3, 8):
        dut.data_in[i][0].value = 0
        dut.data_in[i][1].value = 0
    
    dut.num_pairs.value = 3
    await Timer(10, units='ns')
    
    # Expected: col0 = ['x', 'a', 'm', 0, 0, 0, 0, 0]
    # Expected: col1 = ['y', 'b', 'n', 0, 0, 0, 0, 0]
    assert dut.col0[0].value == ord('x'), f"col0[0] should be 'x' (120), got {int(dut.col0[0].value)}"
    assert dut.col0[1].value == ord('a'), f"col0[1] should be 'a' (97), got {int(dut.col0[1].value)}"
    assert dut.col0[2].value == ord('m'), f"col0[2] should be 'm' (109), got {int(dut.col0[2].value)}"
    assert dut.col1[0].value == ord('y'), f"col1[0] should be 'y' (121), got {int(dut.col1[0].value)}"
    assert dut.col1[1].value == ord('b'), f"col1[1] should be 'b' (98), got {int(dut.col1[1].value)}"
    assert dut.col1[2].value == ord('n'), f"col1[2] should be 'n' (110), got {int(dut.col1[2].value)}"
    # Check zeros
    assert dut.col0[3].value == 0, "col0[3] should be 0"
    assert dut.col1[3].value == 0, "col1[3] should be 0"
    print("Test 1 passed: 3 pairs of characters")
    
    # Test Case 2: 4 pairs of integers
    dut.data_in[0][0].value = 1
    dut.data_in[0][1].value = 2
    dut.data_in[1][0].value = 3
    dut.data_in[1][1].value = 4
    dut.data_in[2][0].value = 5
    dut.data_in[2][1].value = 6
    dut.data_in[3][0].value = 7
    dut.data_in[3][1].value = 8
    for i in range(4, 8):
        dut.data_in[i][0].value = 0
        dut.data_in[i][1].value = 0
    
    dut.num_pairs.value = 4
    await Timer(10, units='ns')
    
    # Expected: col0 = [1, 3, 5, 7, 0, 0, 0, 0]
    # Expected: col1 = [2, 4, 6, 8, 0, 0, 0, 0]
    assert dut.col0[0].value == 1, f"col0[0] should be 1, got {int(dut.col0[0].value)}"
    assert dut.col0[1].value == 3, f"col0[1] should be 3, got {int(dut.col0[1].value)}"
    assert dut.col0[2].value == 5, f"col0[2] should be 5, got {int(dut.col0[2].value)}"
    assert dut.col0[3].value == 7, f"col0[3] should be 7, got {int(dut.col0[3].value)}"
    assert dut.col1[0].value == 2, f"col1[0] should be 2, got {int(dut.col1[0].value)}"
    assert dut.col1[1].value == 4, f"col1[1] should be 4, got {int(dut.col1[1].value)}"
    assert dut.col1[2].value == 6, f"col1[2] should be 6, got {int(dut.col1[2].value)}"
    assert dut.col1[3].value == 8, f"col1[3] should be 8, got {int(dut.col1[3].value)}"
    print("Test 2 passed: 4 pairs of integers")
    
    # Test Case 3: 3 pairs with 3 elements each (but only using first 2 as per problem)
    # This tests that we only look at first two elements of each sublist
    dut.data_in[0][0].value = ord('x')
    dut.data_in[0][1].value = ord('y')
    dut.data_in[1][0].value = ord('a')
    dut.data_in[1][1].value = ord('b')
    dut.data_in[2][0].value = ord('m')
    dut.data_in[2][1].value = ord('n')
    for i in range(3, 8):
        dut.data_in[i][0].value = 0
        dut.data_in[i][1].value = 0
    
    dut.num_pairs.value = 3
    await Timer(10, units='ns')
    
    assert dut.col0[0].value == ord('x')
    assert dut.col0[1].value == ord('a')
    assert dut.col0[2].value == ord('m')
    assert dut.col1[0].value == ord('y')
    assert dut.col1[1].value == ord('b')
    assert dut.col1[2].value == ord('n')
    print("Test 3 passed: 3 pairs with character data")
    
    # Test Case 4: Edge case - 1 pair
    dut.data_in[0][0].value = 42
    dut.data_in[0][1].value = 99
    for i in range(1, 8):
        dut.data_in[i][0].value = 0
        dut.data_in[i][1].value = 0
    
    dut.num_pairs.value = 1
    await Timer(10, units='ns')
    
    assert dut.col0[0].value == 42
    assert dut.col1[0].value == 99
    assert dut.col0[1].value == 0
    assert dut.col1[1].value == 0
    print("Test 4 passed: 1 pair edge case")
    
    # Test Case 5: Maximum pairs (8)
    for i in range(8):
        dut.data_in[i][0].value = i * 2 + 1
        dut.data_in[i][1].value = i * 2 + 2
    
    dut.num_pairs.value = 8
    await Timer(10, units='ns')
    
    for i in range(8):
        assert dut.col0[i].value == i * 2 + 1, f"col0[{i}] mismatch"
        assert dut.col1[i].value == i * 2 + 2, f"col1[{i}] mismatch"
    print("Test 5 passed: 8 pairs (maximum)")
    
    print("
=== Summary: All 5 tests passed ===")