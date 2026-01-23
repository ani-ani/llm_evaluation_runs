import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def to_8bit_signed(value):
    """Convert Python int to 8-bit signed representation"""
    if value < 0:
        return value & 0xFF
    else:
        return value & 0xFF

def to_9bit_signed(value):
    """Convert Python int to 9-bit signed representation"""
    if value < 0:
        return value & 0x1FF
    else:
        return value & 0x1FF

def get_pairs_count_python(arr, sum_val):
    """Reference Python implementation"""
    count = 0
    for i in range(len(arr)):
        for j in range(i + 1, len(arr)):
            if arr[i] + arr[j] == sum_val:
                count += 1
    return count

@cocotb.test()
async def test_pair_sum_counter(dut):
    """Test the pair_sum_counter module with various test cases"""
    
    # Initialize signals
    dut.valid.value = 0
    dut.arr_0.value = 0
    dut.arr_1.value = 0
    dut.arr_2.value = 0
    dut.arr_3.value = 0
    dut.arr_4.value = 0
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    dut.target_sum.value = 0
    
    await Timer(10, units='ns')
    
    # Test Case 1: [1,1,1,1] with sum=2 -> should be 6
    dut.arr_0.value = to_8bit_signed(1)
    dut.arr_1.value = to_8bit_signed(1)
    dut.arr_2.value = to_8bit_signed(1)
    dut.arr_3.value = to_8bit_signed(1)
    dut.arr_4.value = to_8bit_signed(0)  # Fill with 0s
    dut.arr_5.value = to_8bit_signed(0)
    dut.arr_6.value = to_8bit_signed(0)
    dut.arr_7.value = to_8bit_signed(0)
    dut.target_sum.value = to_9bit_signed(2)
    dut.valid.value = 1
    await Timer(10, units='ns')
    result_1 = int(dut.pair_count.value)
    valid_1 = int(dut.result_valid.value)
    print(f"Test 1: arr=[1,1,1,1,0,0,0,0], target=2")
    print(f"  Expected: 6, Got: {result_1}, Valid: {valid_1}")
    assert result_1 == 6, f"Test 1 failed: expected 6, got {result_1}"
    assert valid_1 == 1, f"Test 1 result not valid"
    
    # Test Case 2: [1,5,7,-1,5] with sum=6 -> should be 3
    dut.arr_0.value = to_8bit_signed(1)
    dut.arr_1.value = to_8bit_signed(5)
    dut.arr_2.value = to_8bit_signed(7)
    dut.arr_3.value = to_8bit_signed(-1)
    dut.arr_4.value = to_8bit_signed(5)
    dut.arr_5.value = to_8bit_signed(0)
    dut.arr_6.value = to_8bit_signed(0)
    dut.arr_7.value = to_8bit_signed(0)
    dut.target_sum.value = to_9bit_signed(6)
    await Timer(10, units='ns')
    result_2 = int(dut.pair_count.value)
    valid_2 = int(dut.result_valid.value)
    print(f"Test 2: arr=[1,5,7,-1,5,0,0,0], target=6")
    print(f"  Expected: 3, Got: {result_2}, Valid: {valid_2}")
    assert result_2 == 3, f"Test 2 failed: expected 3, got {result_2}"
    assert valid_2 == 1, f"Test 2 result not valid"
    
    # Test Case 3: [1,-2,3] with sum=1 -> should be 1
    dut.arr_0.value = to_8bit_signed(1)
    dut.arr_1.value = to_8bit_signed(-2)
    dut.arr_2.value = to_8bit_signed(3)
    dut.arr_3.value = to_8bit_signed(0)
    dut.arr_4.value = to_8bit_signed(0)
    dut.arr_5.value = to_8bit_signed(0)
    dut.arr_6.value = to_8bit_signed(0)
    dut.arr_7.value = to_8bit_signed(0)
    dut.target_sum.value = to_9bit_signed(1)
    await Timer(10, units='ns')
    result_3 = int(dut.pair_count.value)
    valid_3 = int(dut.result_valid.value)
    print(f"Test 3: arr=[1,-2,3,0,0,0,0,0], target=1")
    print(f"  Expected: 1, Got: {result_3}, Valid: {valid_3}")
    assert result_3 == 1, f"Test 3 failed: expected 1, got {result_3}"
    assert valid_3 == 1, f"Test 3 result not valid"
    
    # Test Case 4: [-1,-2,3] with sum=-3 -> should be 1
    dut.arr_0.value = to_8bit_signed(-1)
    dut.arr_1.value = to_8bit_signed(-2)
    dut.arr_2.value = to_8bit_signed(3)
    dut.arr_3.value = to_8bit_signed(0)
    dut.arr_4.value = to_8bit_signed(0)
    dut.arr_5.value = to_8bit_signed(0)
    dut.arr_6.value = to_8bit_signed(0)
    dut.arr_7.value = to_8bit_signed(0)
    dut.target_sum.value = to_9bit_signed(-3)
    await Timer(10, units='ns')
    result_4 = int(dut.pair_count.value)
    valid_4 = int(dut.result_valid.value)
    print(f"Test 4: arr=[-1,-2,3,0,0,0,0,0], target=-3")
    print(f"  Expected: 1, Got: {result_4}, Valid: {valid_4}")
    assert result_4 == 1, f"Test 4 failed: expected 1, got {result_4}"
    assert valid_4 == 1, f"Test 4 result not valid"
    
    # Edge case: Empty array (all zeros) should give 0
    dut.arr_0.value = to_8bit_signed(0)
    dut.arr_1.value = to_8bit_signed(0)
    dut.arr_2.value = to_8bit_signed(0)
    dut.arr_3.value = to_8bit_signed(0)
    dut.arr_4.value = to_8bit_signed(0)
    dut.arr_5.value = to_8bit_signed(0)
    dut.arr_6.value = to_8bit_signed(0)
    dut.arr_7.value = to_8bit_signed(0)
    dut.target_sum.value = to_9bit_signed(0)
    await Timer(10, units='ns')
    result_5 = int(dut.pair_count.value)
    print(f"Test 5: arr=[0,0,0,0,0,0,0,0], target=0")
    print(f"  Expected: 28 (all 0+0=0), Got: {result_5}")
    # Note: 0+0=0, so all 28 pairs should match
    assert result_5 == 28, f"Test 5 failed: expected 28, got {result_5}"
    
    # Edge case: Maximum values
    dut.arr_0.value = to_8bit_signed(127)
    dut.arr_1.value = to_8bit_signed(127)
    dut.arr_2.value = to_8bit_signed(-128)
    dut.arr_3.value = to_8bit_signed(-128)
    dut.arr_4.value = to_8bit_signed(127)
    dut.arr_5.value = to_8bit_signed(-128)
    dut.arr_6.value = to_8bit_signed(0)
    dut.arr_7.value = to_8bit_signed(0)
    dut.target_sum.value = to_9bit_signed(-1)  # 127 + (-128) = -1
    await Timer(10, units='ns')
    result_6 = int(dut.pair_count.value)
    print(f"Test 6: arr=[127,127,-128,-128,127,-128,0,0], target=-1")
    print(f"  Result: {result_6}")
    
    # Count expected pairs manually
    # Pairs with sum -1: (0,2), (0,3), (0,5), (1,2), (1,3), (1,5), (2,4), (3,4) = 8
    expected_6 = 8
    print(f"  Expected: {expected_6}")
    assert result_6 == expected_6, f"Test 6 failed: expected {expected_6}, got {result_6}"
    
    print("
=== Summary ===")
    print("All 6 tests passed!")
