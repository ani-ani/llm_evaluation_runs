import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_tuple_divisible_filter(dut):
    """Test filtering of tuples for divisibility by K"""
    
    # Test case 1: From example
    dut.tuple_0_elem_0.value = 6
    dut.tuple_0_elem_1.value = 24
    dut.tuple_0_elem_2.value = 12
    dut.tuple_1_elem_0.value = 7
    dut.tuple_1_elem_1.value = 9
    dut.tuple_1_elem_2.value = 6
    dut.tuple_2_elem_0.value = 12
    dut.tuple_2_elem_1.value = 18
    dut.tuple_2_elem_2.value = 21
    dut.K.value = 6
    await Timer(1, units='ns')
    result = int(dut.valid.value)
    print(f"Test 1: Expected 0b001 (1), Got 0b{result:03b} ({result})")
    assert result == 1, f"Test 1 failed: expected 1, got {result}"
    
    # Test case 2
    dut.tuple_0_elem_0.value = 5
    dut.tuple_0_elem_1.value = 25
    dut.tuple_0_elem_2.value = 30
    dut.tuple_1_elem_0.value = 4
    dut.tuple_1_elem_1.value = 2
    dut.tuple_1_elem_2.value = 3
    dut.tuple_2_elem_0.value = 7
    dut.tuple_2_elem_1.value = 8
    dut.tuple_2_elem_2.value = 9
    dut.K.value = 5
    await Timer(1, units='ns')
    result = int(dut.valid.value)
    print(f"Test 2: Expected 0b001 (1), Got 0b{result:03b} ({result})")
    assert result == 1, f"Test 2 failed: expected 1, got {result}"
    
    # Test case 3
    dut.tuple_0_elem_0.value = 7
    dut.tuple_0_elem_1.value = 9
    dut.tuple_0_elem_2.value = 16
    dut.tuple_1_elem_0.value = 8
    dut.tuple_1_elem_1.value = 16
    dut.tuple_1_elem_2.value = 4
    dut.tuple_2_elem_0.value = 19
    dut.tuple_2_elem_1.value = 17
    dut.tuple_2_elem_2.value = 18
    dut.K.value = 4
    await Timer(1, units='ns')
    result = int(dut.valid.value)
    print(f"Test 3: Expected 0b010 (2), Got 0b{result:03b} ({result})")
    assert result == 2, f"Test 3 failed: expected 2, got {result}"
    
    # Test case 4: Multiple tuples pass
    dut.tuple_0_elem_0.value = 2
    dut.tuple_0_elem_1.value = 4
    dut.tuple_0_elem_2.value = 6
    dut.tuple_1_elem_0.value = 8
    dut.tuple_1_elem_1.value = 10
    dut.tuple_1_elem_2.value = 12
    dut.tuple_2_elem_0.value = 3
    dut.tuple_2_elem_1.value = 5
    dut.tuple_2_elem_2.value = 7
    dut.K.value = 2
    await Timer(1, units='ns')
    result = int(dut.valid.value)
    print(f"Test 4: Expected 0b011 (3), Got 0b{result:03b} ({result})")
    assert result == 3, f"Test 4 failed: expected 3, got {result}"
    
    # Test case 5: K=1 (all numbers divisible by 1)
    dut.tuple_0_elem_0.value = 5
    dut.tuple_0_elem_1.value = 13
    dut.tuple_0_elem_2.value = 27
    dut.tuple_1_elem_0.value = 1
    dut.tuple_1_elem_1.value = 99
    dut.tuple_1_elem_2.value = 8
    dut.tuple_2_elem_0.value = 42
    dut.tuple_2_elem_1.value = 0
    dut.tuple_2_elem_2.value = 64
    dut.K.value = 1
    await Timer(1, units='ns')
    result = int(dut.valid.value)
    print(f"Test 5: Expected 0b111 (7), Got 0b{result:03b} ({result})")
    assert result == 7, f"Test 5 failed: expected 7, got {result}"
    
    # Test case 6: None pass
    dut.tuple_0_elem_0.value = 3
    dut.tuple_0_elem_1.value = 5
    dut.tuple_0_elem_2.value = 7
    dut.tuple_1_elem_0.value = 10
    dut.tuple_1_elem_1.value = 11
    dut.tuple_1_elem_2.value = 12
    dut.tuple_2_elem_0.value = 15
    dut.tuple_2_elem_1.value = 16
    dut.tuple_2_elem_2.value = 17
    dut.K.value = 4
    await Timer(1, units='ns')
    result = int(dut.valid.value)
    print(f"Test 6: Expected 0b000 (0), Got 0b{result:03b} ({result})")
    assert result == 0, f"Test 6 failed: expected 0, got {result}"
    
    print(f"
All tests completed successfully!")
