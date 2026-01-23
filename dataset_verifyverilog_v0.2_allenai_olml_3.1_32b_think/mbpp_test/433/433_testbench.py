import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_check_greater(dut):
    """Test the check_greater combinational module"""
    
    # Test case 1: number=4, arr=[1,2,3,4,5,0,0,0] -> result should be 0 (4 not > 5)
    dut.number.value = 4
    dut.arr[0].value = 1
    dut.arr[1].value = 2
    dut.arr[2].value = 3
    dut.arr[3].value = 4
    dut.arr[4].value = 5
    dut.arr[5].value = 0
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 1 failed: expected 0, got {dut.result.value}"
    print("Test 1 passed: arr=[1,2,3,4,5,0,0,0], number=4 -> result=0")
    
    # Test case 2: number=8, arr=[2,3,4,5,6,0,0,0] -> result should be 1 (8 > all)
    dut.number.value = 8
    dut.arr[0].value = 2
    dut.arr[1].value = 3
    dut.arr[2].value = 4
    dut.arr[3].value = 5
    dut.arr[4].value = 6
    dut.arr[5].value = 0
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 2 failed: expected 1, got {dut.result.value}"
    print("Test 2 passed: arr=[2,3,4,5,6,0,0,0], number=8 -> result=1")
    
    # Test case 3: number=11, arr=[9,7,4,8,6,1,0,0] -> result should be 1 (11 > all)
    dut.number.value = 11
    dut.arr[0].value = 9
    dut.arr[1].value = 7
    dut.arr[2].value = 4
    dut.arr[3].value = 8
    dut.arr[4].value = 6
    dut.arr[5].value = 1
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 3 failed: expected 1, got {dut.result.value}"
    print("Test 3 passed: arr=[9,7,4,8,6,1,0,0], number=11 -> result=1")
    
    # Test case 4: number=10, arr=[10,20,30,40,0,0,0,0] -> result should be 0 (10 not > 10)
    dut.number.value = 10
    dut.arr[0].value = 10
    dut.arr[1].value = 20
    dut.arr[2].value = 30
    dut.arr[3].value = 40
    dut.arr[4].value = 0
    dut.arr[5].value = 0
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 4 failed: expected 0, got {dut.result.value}"
    print("Test 4 passed: arr=[10,20,30,40,0,0,0,0], number=10 -> result=0")
    
    # Test case 5: number=6, arr=[5,5,5,5,0,0,0,0] -> result should be 1 (6 > all 5s)
    dut.number.value = 6
    dut.arr[0].value = 5
    dut.arr[1].value = 5
    dut.arr[2].value = 5
    dut.arr[3].value = 5
    dut.arr[4].value = 0
    dut.arr[5].value = 0
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 5 failed: expected 1, got {dut.result.value}"
    print("Test 5 passed: arr=[5,5,5,5,0,0,0,0], number=6 -> result=1")
    
    print("All 5 tests passed!")