import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_tuple_to_dict(dut):
    """Test tuple to dictionary conversion with adjacent pairs"""
    
    # Test 1: (1, 5, 7, 10, 13, 5) -> {1:5, 7:10, 13:5}
    dut.tuple_data[0].value = 1
    dut.tuple_data[1].value = 5
    dut.tuple_data[2].value = 7
    dut.tuple_data[3].value = 10
    dut.tuple_data[4].value = 13
    dut.tuple_data[5].value = 5
    dut.tuple_data[6].value = 0
    dut.tuple_data[7].value = 0
    dut.valid_count.value = 6
    
    await Timer(10, units='ns')
    
    assert dut.key_0.value == 1, f"Test 1 failed: key_0 expected 1, got {dut.key_0.value}"
    assert dut.val_0.value == 5, f"Test 1 failed: val_0 expected 5, got {dut.val_0.value}"
    assert dut.key_1.value == 7, f"Test 1 failed: key_1 expected 7, got {dut.key_1.value}"
    assert dut.val_1.value == 10, f"Test 1 failed: val_1 expected 10, got {dut.val_1.value}"
    assert dut.key_2.value == 13, f"Test 1 failed: key_2 expected 13, got {dut.key_2.value}"
    assert dut.val_2.value == 5, f"Test 1 failed: val_2 expected 5, got {dut.val_2.value}"
    assert dut.key_3.value == 0, f"Test 1 failed: key_3 expected 0, got {dut.key_3.value}"
    assert dut.val_3.value == 0, f"Test 1 failed: val_3 expected 0, got {dut.val_3.value}"
    assert dut.pair_count.value == 3, f"Test 1 failed: pair_count expected 3, got {dut.pair_count.value}"
    print("Test 1 passed: (1,5,7,10,13,5) -> {1:5, 7:10, 13:5}")
    
    # Test 2: (1, 2, 3, 4, 5, 6) -> {1:2, 3:4, 5:6}
    dut.tuple_data[0].value = 1
    dut.tuple_data[1].value = 2
    dut.tuple_data[2].value = 3
    dut.tuple_data[3].value = 4
    dut.tuple_data[4].value = 5
    dut.tuple_data[5].value = 6
    dut.tuple_data[6].value = 0
    dut.tuple_data[7].value = 0
    dut.valid_count.value = 6
    
    await Timer(10, units='ns')
    
    assert dut.key_0.value == 1, f"Test 2 failed: key_0 expected 1, got {dut.key_0.value}"
    assert dut.val_0.value == 2, f"Test 2 failed: val_0 expected 2, got {dut.val_0.value}"
    assert dut.key_1.value == 3, f"Test 2 failed: key_1 expected 3, got {dut.key_1.value}"
    assert dut.val_1.value == 4, f"Test 2 failed: val_1 expected 4, got {dut.val_1.value}"
    assert dut.key_2.value == 5, f"Test 2 failed: key_2 expected 5, got {dut.key_2.value}"
    assert dut.val_2.value == 6, f"Test 2 failed: val_2 expected 6, got {dut.val_2.value}"
    assert dut.pair_count.value == 3, f"Test 2 failed: pair_count expected 3, got {dut.pair_count.value}"
    print("Test 2 passed: (1,2,3,4,5,6) -> {1:2, 3:4, 5:6}")
    
    # Test 3: (7, 8, 9, 10, 11, 12) -> {7:8, 9:10, 11:12}
    dut.tuple_data[0].value = 7
    dut.tuple_data[1].value = 8
    dut.tuple_data[2].value = 9
    dut.tuple_data[3].value = 10
    dut.tuple_data[4].value = 11
    dut.tuple_data[5].value = 12
    dut.tuple_data[6].value = 0
    dut.tuple_data[7].value = 0
    dut.valid_count.value = 6
    
    await Timer(10, units='ns')
    
    assert dut.key_0.value == 7, f"Test 3 failed: key_0 expected 7, got {dut.key_0.value}"
    assert dut.val_0.value == 8, f"Test 3 failed: val_0 expected 8, got {dut.val_0.value}"
    assert dut.key_1.value == 9, f"Test 3 failed: key_1 expected 9, got {dut.key_1.value}"
    assert dut.val_1.value == 10, f"Test 3 failed: val_1 expected 10, got {dut.val_1.value}"
    assert dut.key_2.value == 11, f"Test 3 failed: key_2 expected 11, got {dut.key_2.value}"
    assert dut.val_2.value == 12, f"Test 3 failed: val_2 expected 12, got {dut.val_2.value}"
    assert dut.pair_count.value == 3, f"Test 3 failed: pair_count expected 3, got {dut.pair_count.value}"
    print("Test 3 passed: (7,8,9,10,11,12) -> {7:8, 9:10, 11:12}")
    
    # Test 4: 4 elements -> 2 pairs
    dut.tuple_data[0].value = 100
    dut.tuple_data[1].value = 200
    dut.tuple_data[2].value = 150
    dut.tuple_data[3].value = 250
    dut.tuple_data[4].value = 0
    dut.tuple_data[5].value = 0
    dut.tuple_data[6].value = 0
    dut.tuple_data[7].value = 0
    dut.valid_count.value = 4
    
    await Timer(10, units='ns')
    
    assert dut.key_0.value == 100, f"Test 4 failed: key_0 expected 100, got {dut.key_0.value}"
    assert dut.val_0.value == 200, f"Test 4 failed: val_0 expected 200, got {dut.val_0.value}"
    assert dut.key_1.value == 150, f"Test 4 failed: key_1 expected 150, got {dut.key_1.value}"
    assert dut.val_1.value == 250, f"Test 4 failed: val_1 expected 250, got {dut.val_1.value}"
    assert dut.key_2.value == 0, f"Test 4 failed: key_2 expected 0, got {dut.key_2.value}"
    assert dut.pair_count.value == 2, f"Test 4 failed: pair_count expected 2, got {dut.pair_count.value}"
    print("Test 4 passed: 4 elements -> 2 pairs")
    
    # Test 5: 2 elements -> 1 pair
    dut.tuple_data[0].value = 255
    dut.tuple_data[1].value = 128
    dut.tuple_data[2].value = 0
    dut.tuple_data[3].value = 0
    dut.tuple_data[4].value = 0
    dut.tuple_data[5].value = 0
    dut.tuple_data[6].value = 0
    dut.tuple_data[7].value = 0
    dut.valid_count.value = 2
    
    await Timer(10, units='ns')
    
    assert dut.key_0.value == 255, f"Test 5 failed: key_0 expected 255, got {dut.key_0.value}"
    assert dut.val_0.value == 128, f"Test 5 failed: val_0 expected 128, got {dut.val_0.value}"
    assert dut.key_1.value == 0, f"Test 5 failed: key_1 expected 0, got {dut.key_1.value}"
    assert dut.pair_count.value == 1, f"Test 5 failed: pair_count expected 1, got {dut.pair_count.value}"
    print("Test 5 passed: 2 elements -> 1 pair")
    
    print("
All 5 tests passed!")