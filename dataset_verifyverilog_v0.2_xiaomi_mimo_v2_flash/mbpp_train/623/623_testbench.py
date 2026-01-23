import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_nth_power_array(dut):
    """Test nth_power_array module with multiple power values"""
    
    # Initialize inputs
    dut.power_i.value = 0
    for i in range(8):
        dut.nums_i[i].value = 0
    
    await Timer(10, units='ns')
    
    # Test Case 1: power = 2, inputs [1,2,3,4,5,6,7,8]
    # Expected: [1,4,9,16,25,36,49,64]
    dut.power_i.value = 2
    test_nums_1 = [1, 2, 3, 4, 5, 6, 7, 8]
    expected_1 = [1, 4, 9, 16, 25, 36, 49, 64]
    for i, num in enumerate(test_nums_1):
        dut.nums_i[i].value = num
    
    await Timer(10, units='ns')
    
    for i, exp in enumerate(expected_1):
        actual = int(dut.results_o[i].value)
        assert actual == exp, f"Test 1: results_o[{i}] = {actual}, expected {exp}"
    print(f"Test 1 passed: power=2 with inputs [1..8]")
    
    # Test Case 2: power = 3, inputs [10,20,30,0,0,0,0,0]
    # Expected: [1000, 8000, 27000, 0, 0, 0, 0, 0]
    dut.power_i.value = 3
    test_nums_2 = [10, 20, 30, 0, 0, 0, 0, 0]
    expected_2 = [1000, 8000, 27000, 0, 0, 0, 0, 0]
    for i, num in enumerate(test_nums_2):
        dut.nums_i[i].value = num
    
    await Timer(10, units='ns')
    
    for i, exp in enumerate(expected_2):
        actual = int(dut.results_o[i].value)
        assert actual == exp, f"Test 2: results_o[{i}] = {actual}, expected {exp}"
    print(f"Test 2 passed: power=3 with inputs [10,20,30]")
    
    # Test Case 3: power = 5, inputs [12,15,0,0,0,0,0,0]
    # Expected: [248832, 759375, 0, 0, 0, 0, 0, 0]
    dut.power_i.value = 5
    test_nums_3 = [12, 15, 0, 0, 0, 0, 0, 0]
    expected_3 = [248832, 759375, 0, 0, 0, 0, 0, 0]
    for i, num in enumerate(test_nums_3):
        dut.nums_i[i].value = num
    
    await Timer(10, units='ns')
    
    for i, exp in enumerate(expected_3):
        actual = int(dut.results_o[i].value)
        assert actual == exp, f"Test 3: results_o[{i}] = {actual}, expected {exp}"
    print(f"Test 3 passed: power=5 with inputs [12,15]")
    
    # Test Case 4: power = 0, inputs [5,10,15,0,0,0,0,0]
    # Expected: [1,1,1,0,0,0,0,0] - power 0 returns 1 for any non-zero input
    dut.power_i.value = 0
    test_nums_4 = [5, 10, 15, 0, 0, 0, 0, 0]
    expected_4 = [1, 1, 1, 0, 0, 0, 0, 0]
    for i, num in enumerate(test_nums_4):
        dut.nums_i[i].value = num
    
    await Timer(10, units='ns')
    
    for i, exp in enumerate(expected_4):
        actual = int(dut.results_o[i].value)
        assert actual == exp, f"Test 4: results_o[{i}] = {actual}, expected {exp}"
    print(f"Test 4 passed: power=0 (special case)")
    
    # Test Case 5: power = 1, inputs [-2, -1, 0, 1, 2, 0, 0, 0]
    # Expected: [-2, -1, 0, 1, 2, 0, 0, 0]
    dut.power_i.value = 1
    test_nums_5 = [-2, -1, 0, 1, 2, 0, 0, 0]
    expected_5 = [-2, -1, 0, 1, 2, 0, 0, 0]
    for i, num in enumerate(test_nums_5):
        # Convert to 2's complement for negative values
        if num < 0:
            dut.nums_i[i].value = (1 << 16) + num  # 16-bit 2's complement
        else:
            dut.nums_i[i].value = num
    
    await Timer(10, units='ns')
    
    for i, exp in enumerate(expected_5):
        actual = int(dut.results_o[i].value)
        # Sign-extend for negative expected values
        if exp < 0:
            exp_extended = (1 << 32) + exp
        else:
            exp_extended = exp
        assert actual == exp_extended, f"Test 5: results_o[{i}] = {actual}, expected {exp_extended}"
    print(f"Test 5 passed: power=1 with negative numbers")
    
    print("
All 5 tests passed!")
