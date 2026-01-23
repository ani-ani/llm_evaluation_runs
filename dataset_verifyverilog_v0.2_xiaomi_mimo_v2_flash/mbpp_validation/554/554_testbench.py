import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_odd_filter(dut):
    """Test odd number filtering module"""
    
    # Test case 1: [1,2,3,4,5,6] -> [1,3,5]
    dut.array_in[0].value = 1
    dut.array_in[1].value = 2
    dut.array_in[2].value = 3
    dut.array_in[3].value = 4
    dut.array_in[4].value = 5
    dut.array_in[5].value = 6
    dut.array_in[6].value = 0
    dut.array_in[7].value = 0
    dut.count.value = 6
    
    await Timer(10, units='ns')
    
    # Check results
    assert dut.out_count.value == 3, f"Expected out_count=3, got {dut.out_count.value}"
    assert dut.array_out[0].value == 1, f"Expected [0]=1, got {dut.array_out[0].value}"
    assert dut.array_out[1].value == 3, f"Expected [1]=3, got {dut.array_out[1].value}"
    assert dut.array_out[2].value == 5, f"Expected [2]=5, got {dut.array_out[2].value}"
    for i in range(3, 8):
        assert dut.array_out[i].value == 0, f"Expected [{i}]=0, got {dut.array_out[i].value}"
    
    print("Test 1 passed: [1,2,3,4,5,6] -> [1,3,5]")
    
    # Test case 2: [10,11,12,13] -> [11,13]
    dut.array_in[0].value = 10
    dut.array_in[1].value = 11
    dut.array_in[2].value = 12
    dut.array_in[3].value = 13
    dut.array_in[4].value = 0
    dut.array_in[5].value = 0
    dut.array_in[6].value = 0
    dut.array_in[7].value = 0
    dut.count.value = 4
    
    await Timer(10, units='ns')
    
    assert dut.out_count.value == 2, f"Expected out_count=2, got {dut.out_count.value}"
    assert dut.array_out[0].value == 11, f"Expected [0]=11, got {dut.array_out[0].value}"
    assert dut.array_out[1].value == 13, f"Expected [1]=13, got {dut.array_out[1].value}"
    for i in range(2, 8):
        assert dut.array_out[i].value == 0, f"Expected [{i}]=0, got {dut.array_out[i].value}"
    
    print("Test 2 passed: [10,11,12,13] -> [11,13]")
    
    # Test case 3: [7,8,9,1] -> [7,9,1]
    dut.array_in[0].value = 7
    dut.array_in[1].value = 8
    dut.array_in[2].value = 9
    dut.array_in[3].value = 1
    dut.array_in[4].value = 0
    dut.array_in[5].value = 0
    dut.array_in[6].value = 0
    dut.array_in[7].value = 0
    dut.count.value = 4
    
    await Timer(10, units='ns')
    
    assert dut.out_count.value == 3, f"Expected out_count=3, got {dut.out_count.value}"
    assert dut.array_out[0].value == 7, f"Expected [0]=7, got {dut.array_out[0].value}"
    assert dut.array_out[1].value == 9, f"Expected [1]=9, got {dut.array_out[1].value}"
    assert dut.array_out[2].value == 1, f"Expected [2]=1, got {dut.array_out[2].value}"
    for i in range(3, 8):
        assert dut.array_out[i].value == 0, f"Expected [{i}]=0, got {dut.array_out[i].value}"
    
    print("Test 3 passed: [7,8,9,1] -> [7,9,1]")
    
    # Additional edge case: all odd
    dut.array_in[0].value = 1
    dut.array_in[1].value = 3
    dut.array_in[2].value = 5
    dut.array_in[3].value = 7
    dut.array_in[4].value = 9
    dut.array_in[5].value = 11
    dut.array_in[6].value = 13
    dut.array_in[7].value = 15
    dut.count.value = 8
    
    await Timer(10, units='ns')
    
    assert dut.out_count.value == 8, f"Expected out_count=8, got {dut.out_count.value}"
    for i in range(8):
        assert dut.array_out[i].value == (2*i+1), f"Expected [{i}]={2*i+1}, got {dut.array_out[i].value}"
    
    print("Edge case 1 passed: all odd numbers")
    
    # Additional edge case: all even
    dut.array_in[0].value = 2
    dut.array_in[1].value = 4
    dut.array_in[2].value = 6
    dut.array_in[3].value = 8
    dut.array_in[4].value = 10
    dut.array_in[5].value = 12
    dut.array_in[6].value = 14
    dut.array_in[7].value = 16
    dut.count.value = 8
    
    await Timer(10, units='ns')
    
    assert dut.out_count.value == 0, f"Expected out_count=0, got {dut.out_count.value}"
    for i in range(8):
        assert dut.array_out[i].value == 0, f"Expected [{i}]=0, got {dut.array_out[i].value}"
    
    print("Edge case 2 passed: all even numbers")
    
    # Additional edge case: empty input
    dut.array_in[0].value = 0
    dut.array_in[1].value = 0
    dut.array_in[2].value = 0
    dut.array_in[3].value = 0
    dut.array_in[4].value = 0
    dut.array_in[5].value = 0
    dut.array_in[6].value = 0
    dut.array_in[7].value = 0
    dut.count.value = 0
    
    await Timer(10, units='ns')
    
    assert dut.out_count.value == 0, f"Expected out_count=0, got {dut.out_count.value}"
    for i in range(8):
        assert dut.array_out[i].value == 0, f"Expected [{i}]=0, got {dut.array_out[i].value}"
    
    print("Edge case 3 passed: empty input")
    
    print("
All tests passed!")