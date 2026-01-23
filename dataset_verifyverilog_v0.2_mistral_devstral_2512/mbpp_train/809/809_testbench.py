import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_tuple_compare(dut):
    """Test tuple comparison module"""
    
    # Test 1: (1,2,3) vs (2,3,4) -> False (0)
    dut.tuple1[0].value = 1
    dut.tuple1[1].value = 2
    dut.tuple1[2].value = 3
    dut.tuple2[0].value = 2
    dut.tuple2[1].value = 3
    dut.tuple2[2].value = 4
    dut.length.value = 3
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 1 failed: expected 0, got {dut.result.value}"
    print("Test 1 passed: (1,2,3) vs (2,3,4) = False")
    
    # Test 2: (4,5,6) vs (3,4,5) -> True (1)
    dut.tuple1[0].value = 4
    dut.tuple1[1].value = 5
    dut.tuple1[2].value = 6
    dut.tuple2[0].value = 3
    dut.tuple2[1].value = 4
    dut.tuple2[2].value = 5
    dut.length.value = 3
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 2 failed: expected 1, got {dut.result.value}"
    print("Test 2 passed: (4,5,6) vs (3,4,5) = True")
    
    # Test 3: (11,12,13) vs (10,11,12) -> True (1)
    dut.tuple1[0].value = 11
    dut.tuple1[1].value = 12
    dut.tuple1[2].value = 13
    dut.tuple2[0].value = 10
    dut.tuple2[1].value = 11
    dut.tuple2[2].value = 12
    dut.length.value = 3
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 3 failed: expected 1, got {dut.result.value}"
    print("Test 3 passed: (11,12,13) vs (10,11,12) = True")
    
    # Test 4: Single element, equal values -> False
    dut.tuple1[0].value = 5
    dut.tuple2[0].value = 5
    dut.length.value = 1
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 4 failed: expected 0, got {dut.result.value}"
    print("Test 4 passed: Single equal element = False")
    
    # Test 5: All elements, all smaller -> True
    for i in range(8):
        dut.tuple1[i].value = 20 + i
        dut.tuple2[i].value = 10 + i
    dut.length.value = 8
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 5 failed: expected 1, got {dut.result.value}"
    print("Test 5 passed: All 8 elements smaller = True")
    
    # Test 6: Multiple elements, last one fails -> False
    dut.tuple1[0].value = 10
    dut.tuple1[1].value = 20
    dut.tuple1[2].value = 30
    dut.tuple2[0].value = 9
    dut.tuple2[1].value = 19
    dut.tuple2[2].value = 30  # Equal, not smaller
    dut.length.value = 3
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 6 failed: expected 0, got {dut.result.value}"
    print("Test 6 passed: Last element equal = False")
    
    # Test 7: Empty comparison (length = 0) -> True (vacuous truth)
    dut.length.value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 7 failed: expected 1, got {dut.result.value}"
    print("Test 7 passed: Empty comparison = True")
    
    passed = 7
    total = 7
    print(f"
Summary: {passed}/{total} tests passed")