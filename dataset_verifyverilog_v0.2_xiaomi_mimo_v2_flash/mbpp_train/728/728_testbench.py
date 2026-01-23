import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_sum_list(dut):
    """Test element-wise list addition"""
    
    # Test case 1: [10,20,30] + [15,25,35] = [25,45,65]
    dut.lst1_0.value = 10
    dut.lst1_1.value = 20
    dut.lst1_2.value = 30
    dut.lst1_3.value = 0
    dut.lst1_4.value = 0
    dut.lst1_5.value = 0
    dut.lst1_6.value = 0
    dut.lst1_7.value = 0
    
    dut.lst2_0.value = 15
    dut.lst2_1.value = 25
    dut.lst2_2.value = 35
    dut.lst2_3.value = 0
    dut.lst2_4.value = 0
    dut.lst2_5.value = 0
    dut.lst2_6.value = 0
    dut.lst2_7.value = 0
    
    await Timer(1, units='ns')
    
    assert dut.result_0.value == 25, f"Expected 25, got {dut.result_0.value}"
    assert dut.result_1.value == 45, f"Expected 45, got {dut.result_1.value}"
    assert dut.result_2.value == 65, f"Expected 65, got {dut.result_2.value}"
    assert dut.result_3.value == 0, f"Expected 0, got {dut.result_3.value}"
    assert dut.result_4.value == 0, f"Expected 0, got {dut.result_4.value}"
    assert dut.result_5.value == 0, f"Expected 0, got {dut.result_5.value}"
    assert dut.result_6.value == 0, f"Expected 0, got {dut.result_6.value}"
    assert dut.result_7.value == 0, f"Expected 0, got {dut.result_7.value}"
    print("Test 1 passed: [10,20,30,0,0,0,0,0] + [15,25,35,0,0,0,0,0] = [25,45,65,0,0,0,0,0]")
    
    # Test case 2: [1,2,3] + [5,6,7] = [6,8,10]
    dut.lst1_0.value = 1
    dut.lst1_1.value = 2
    dut.lst1_2.value = 3
    dut.lst1_3.value = 0
    dut.lst1_4.value = 0
    dut.lst1_5.value = 0
    dut.lst1_6.value = 0
    dut.lst1_7.value = 0
    
    dut.lst2_0.value = 5
    dut.lst2_1.value = 6
    dut.lst2_2.value = 7
    dut.lst2_3.value = 0
    dut.lst2_4.value = 0
    dut.lst2_5.value = 0
    dut.lst2_6.value = 0
    dut.lst2_7.value = 0
    
    await Timer(1, units='ns')
    
    assert dut.result_0.value == 6, f"Expected 6, got {dut.result_0.value}"
    assert dut.result_1.value == 8, f"Expected 8, got {dut.result_1.value}"
    assert dut.result_2.value == 10, f"Expected 10, got {dut.result_2.value}"
    assert dut.result_3.value == 0, f"Expected 0, got {dut.result_3.value}"
    assert dut.result_4.value == 0, f"Expected 0, got {dut.result_4.value}"
    assert dut.result_5.value == 0, f"Expected 0, got {dut.result_5.value}"
    assert dut.result_6.value == 0, f"Expected 0, got {dut.result_6.value}"
    assert dut.result_7.value == 0, f"Expected 0, got {dut.result_7.value}"
    print("Test 2 passed: [1,2,3,0,0,0,0,0] + [5,6,7,0,0,0,0,0] = [6,8,10,0,0,0,0,0]")
    
    # Test case 3: [15,20,30] + [15,45,75] = [30,65,105]
    dut.lst1_0.value = 15
    dut.lst1_1.value = 20
    dut.lst1_2.value = 30
    dut.lst1_3.value = 0
    dut.lst1_4.value = 0
    dut.lst1_5.value = 0
    dut.lst1_6.value = 0
    dut.lst1_7.value = 0
    
    dut.lst2_0.value = 15
    dut.lst2_1.value = 45
    dut.lst2_2.value = 75
    dut.lst2_3.value = 0
    dut.lst2_4.value = 0
    dut.lst2_5.value = 0
    dut.lst2_6.value = 0
    dut.lst2_7.value = 0
    
    await Timer(1, units='ns')
    
    assert dut.result_0.value == 30, f"Expected 30, got {dut.result_0.value}"
    assert dut.result_1.value == 65, f"Expected 65, got {dut.result_1.value}"
    assert dut.result_2.value == 105, f"Expected 105, got {dut.result_2.value}"
    assert dut.result_3.value == 0, f"Expected 0, got {dut.result_3.value}"
    assert dut.result_4.value == 0, f"Expected 0, got {dut.result_4.value}"
    assert dut.result_5.value == 0, f"Expected 0, got {dut.result_5.value}"
    assert dut.result_6.value == 0, f"Expected 0, got {dut.result_6.value}"
    assert dut.result_7.value == 0, f"Expected 0, got {dut.result_7.value}"
    print("Test 3 passed: [15,20,30,0,0,0,0,0] + [15,45,75,0,0,0,0,0] = [30,65,105,0,0,0,0,0]")
    
    # Edge case: All 8 elements
    dut.lst1_0.value = 100
    dut.lst1_1.value = 150
    dut.lst1_2.value = 200
    dut.lst1_3.value = 5
    dut.lst1_4.value = 10
    dut.lst1_5.value = 15
    dut.lst1_6.value = 20
    dut.lst1_7.value = 25
    
    dut.lst2_0.value = 50
    dut.lst2_1.value = 100
    dut.lst2_2.value = 55
    dut.lst2_3.value = 5
    dut.lst2_4.value = 10
    dut.lst2_5.value = 15
    dut.lst2_6.value = 20
    dut.lst2_7.value = 25
    
    await Timer(1, units='ns')
    
    assert dut.result_0.value == 150, f"Expected 150, got {dut.result_0.value}"
    assert dut.result_1.value == 250, f"Expected 250, got {dut.result_1.value}"
    assert dut.result_2.value == 255, f"Expected 255, got {dut.result_2.value}"
    assert dut.result_3.value == 10, f"Expected 10, got {dut.result_3.value}"
    assert dut.result_4.value == 20, f"Expected 20, got {dut.result_4.value}"
    assert dut.result_5.value == 30, f"Expected 30, got {dut.result_5.value}"
    assert dut.result_6.value == 40, f"Expected 40, got {dut.result_6.value}"
    assert dut.result_7.value == 50, f"Expected 50, got {dut.result_7.value}"
    print("Test 4 passed: All 8 elements tested")
    
    print("
All 4/4 tests passed!")