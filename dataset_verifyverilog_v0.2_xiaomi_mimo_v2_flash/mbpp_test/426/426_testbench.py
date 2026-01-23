import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_filter_odd(dut):
    """Test filtering odd numbers from a fixed array"""
    
    # Test Case 1: [1, 2, 3, 4, 5, 6, 7, 8] -> Expect [1,3,5,7] (bits 0,2,4,6 set)
    # Indices: 0,1,2,3,4,5,6,7 -> Odd indices are 0,2,4,6
    dut.nums[0] = 1
    dut.nums[1] = 2
    dut.nums[2] = 3
    dut.nums[3] = 4
    dut.nums[4] = 5
    dut.nums[5] = 6
    dut.nums[6] = 7
    dut.nums[7] = 8
    
    await Timer(10, units='ns')
    
    # Expected: odd_nums = 0b01010101 (0x55), count = 4
    assert dut.odd_nums.value == 0x55, f"Test 1 Failed: Expected 0x55, got {hex(dut.odd_nums.value)}"
    assert dut.count.value == 4, f"Test 1 Failed: Expected count 4, got {dut.count.value}"
    print("Test 1 passed: [1,2,3,4,5,6,7,8] -> mask 0x55, count 4")

    # Test Case 2: [10,20,45,67,84,93,0,0] -> Expect [45,67,93] (indices 2,3,5)
    dut.nums[0] = 10
    dut.nums[1] = 20
    dut.nums[2] = 45
    dut.nums[3] = 67
    dut.nums[4] = 84
    dut.nums[5] = 93
    dut.nums[6] = 0
    dut.nums[7] = 0
    
    await Timer(10, units='ns')
    
    # Expected: odd_nums = 0b00101100 (0x2C), count = 3
    assert dut.odd_nums.value == 0x2C, f"Test 2 Failed: Expected 0x2C, got {hex(dut.odd_nums.value)}"
    assert dut.count.value == 3, f"Test 2 Failed: Expected count 3, got {dut.count.value}"
    print("Test 2 passed: [10,20,45,67,84,93,0,0] -> mask 0x2C, count 3")

    # Test Case 3: [5,7,9,8,6,4,3,0] -> Expect [5,7,9,3] (indices 0,1,2,6)
    dut.nums[0] = 5
    dut.nums[1] = 7
    dut.nums[2] = 9
    dut.nums[3] = 8
    dut.nums[4] = 6
    dut.nums[5] = 4
    dut.nums[6] = 3
    dut.nums[7] = 0
    
    await Timer(10, units='ns')
    
    # Expected: odd_nums = 0b01000111 (0x47), count = 4
    assert dut.odd_nums.value == 0x47, f"Test 3 Failed: Expected 0x47, got {hex(dut.odd_nums.value)}"
    assert dut.count.value == 4, f"Test 3 Failed: Expected count 4, got {dut.count.value}"
    print("Test 3 passed: [5,7,9,8,6,4,3,0] -> mask 0x47, count 4")

    # Edge Case 4: All Even [2,4,6,8,10,12,14,16]
    for i in range(8):
        dut.nums[i] = (i+1)*2
    
    await Timer(10, units='ns')
    
    assert dut.odd_nums.value == 0, f"Edge Case Failed: Expected 0, got {hex(dut.odd_nums.value)}"
    assert dut.count.value == 0, f"Edge Case Failed: Expected count 0, got {dut.count.value}"
    print("Edge Case passed: All even numbers -> mask 0x00, count 0")

    print(f"Summary: 4/4 tests passed")