import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_find_unique(dut):
    """Test finding the unique element using XOR property"""
    
    # Helper to set array input
    def set_arr(val_list):
        for i, val in enumerate(val_list):
            setattr(dut, f'arr[{i}]', val)
    
    # Helper to get result
    def get_result():
        return int(dut.unique_val)
    
    # Test Case 1: [1,1,2,2,3] -> 3
    dut._log.info("Running Test Case 1: [1,1,2,2,3]")
    set_arr([1, 1, 2, 2, 3, 0, 0, 0])  # Pad with 0s (0 ^ 0 = 0, doesn't affect result)
    await Timer(1, units='ns')
    result = get_result()
    expected = 3
    assert result == expected, f"Test 1 Failed: Expected {expected}, got {result}"
    
    # Test Case 2: [1,1,3,3,4,4,5,5,7,7,8] -> 8 (Trimmed to fit 8 slots)
    # Adapting to fit 8 slots: Let's use [7,7,8,8,9,9,10,10] where unique is 7, or similar
    # Let's create a valid 8-element case: [4,4,5,5,6,6,7,7] -> All pairs. Result 0.
    # Let's try: [5,5,6,6,7,7,8,8] -> Result 0. 
    # Let's try: [2,2,3,3,4,4,5,5,6] -> 9 elements. Need 8.
    # Let's try: [2,2,3,3,4,4,5,6] -> 6 is unique.
    dut._log.info("Running Test Case 2: [2,2,3,3,4,4,5,6]")
    set_arr([2, 2, 3, 3, 4, 4, 5, 6])
    await Timer(1, units='ns')
    result = get_result()
    expected = 6
    assert result == expected, f"Test 2 Failed: Expected {expected}, got {result}"

    # Test Case 3: [1,2,2,3,3,4,4] -> 1 (Trimmed to 8 slots)
    # [1,1,2,2,3,3,4,4] -> Result 0.
    # [1,2,2,3,3,4,4,5] -> 1 ^ 2 ^ 2 ^ 3 ^ 3 ^ 4 ^ 4 ^ 5 = 1 ^ 5 = 4.
    dut._log.info("Running Test Case 3: [1,2,2,3,3,4,4,5]")
    set_arr([1, 2, 2, 3, 3, 4, 4, 5])
    await Timer(1, units='ns')
    result = get_result()
    expected = 4
    assert result == expected, f"Test 3 Failed: Expected {expected}, got {result}"
    
    # Test Case 4: All zeros
    dut._log.info("Running Test Case 4: All zeros")
    set_arr([0, 0, 0, 0, 0, 0, 0, 0])
    await Timer(1, units='ns')
    result = get_result()
    expected = 0
    assert result == expected, f"Test 4 Failed: Expected {expected}, got {result}"
    
    # Test Case 5: Max Value case
    # [255, 255, 127, 127, 50, 50, 30, 20] -> 20 is unique? 
    # 255^255=0, 127^127=0, 50^50=0, 30^20 = 30 ^ 20 = 10 (0b0001010 ^ 0b00010100 = 0b000001110)
    dut._log.info("Running Test Case 5: Max values")
    set_arr([255, 255, 127, 127, 50, 50, 30, 20])
    await Timer(1, units='ns')
    result = get_result()
    expected = 10
    assert result == expected, f"Test 5 Failed: Expected {expected}, got {result}"
