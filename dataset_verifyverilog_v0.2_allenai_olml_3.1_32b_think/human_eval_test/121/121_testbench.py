import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_sum_odd_even_pos(dut):
    """Test sum of odd elements at even positions"""
    
    # Test case 1: [5, 8, 7, 1] -> positions 0,2 valid, both odd -> 5+7=12
    dut.data[0].value = 5
    dut.data[1].value = 8
    dut.data[2].value = 7
    dut.data[3].value = 1
    dut.length.value = 4
    await Timer(10, units='ns')
    assert dut.result.value == 12, f"Expected 12, got {dut.result.value}"
    
    # Test case 2: [3, 3, 3, 3, 3] -> positions 0,2,4 valid, all odd -> 3+3+3=9
    for i in range(5):
        dut.data[i].value = 3
    dut.length.value = 5
    await Timer(10, units='ns')
    assert dut.result.value == 9, f"Expected 9, got {dut.result.value}"
    
    # Test case 3: [30, 13, 24, 321] -> position 0 (30 even), position 2 (24 even) -> 0
    dut.data[0].value = 30
    dut.data[1].value = 13
    dut.data[2].value = 24
    dut.data[3].value = 321
    dut.length.value = 4
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Expected 0, got {dut.result.value}"
    
    # Test case 4: [5, 9] -> only position 0 valid, 5 is odd -> 5
    dut.data[0].value = 5
    dut.data[1].value = 9
    dut.length.value = 2
    await Timer(10, units='ns')
    assert dut.result.value == 5, f"Expected 5, got {dut.result.value}"
    
    # Test case 5: [2, 4, 8] -> position 0 (2 even) -> 0
    dut.data[0].value = 2
    dut.data[1].value = 4
    dut.data[2].value = 8
    dut.length.value = 3
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Expected 0, got {dut.result.value}"
    
    # Test case 6: [30, 13, 23, 32] -> position 2 (23 odd) -> 23
    dut.data[0].value = 30
    dut.data[1].value = 13
    dut.data[2].value = 23
    dut.data[3].value = 32
    dut.length.value = 4
    await Timer(10, units='ns')
    assert dut.result.value == 23, f"Expected 23, got {dut.result.value}"
    
    # Test case 7: [3, 13, 2, 9] -> position 0 (3 odd) -> 3
    dut.data[0].value = 3
    dut.data[1].value = 13
    dut.data[2].value = 2
    dut.data[3].value = 9
    dut.length.value = 4
    await Timer(10, units='ns')
    assert dut.result.value == 3, f"Expected 3, got {dut.result.value}"
    
    # Edge case: single element (odd, position 0) -> value itself
    dut.data[0].value = 7
    dut.length.value = 1
    await Timer(10, units='ns')
    assert dut.result.value == 7, f"Expected 7, got {dut.result.value}"
    
    # Edge case: single element (even, position 0) -> 0
    dut.data[0].value = 4
    dut.length.value = 1
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Expected 0, got {dut.result.value}"
    
    # Edge case: all odd at even positions (8 elements)
    for i in range(8):
        dut.data[i].value = 1 if i % 2 == 0 else 0
    dut.length.value = 8
    await Timer(10, units='ns')
    assert dut.result.value == 4, f"Expected 4, got {dut.result.value}"
    
    print(f"All tests passed!")