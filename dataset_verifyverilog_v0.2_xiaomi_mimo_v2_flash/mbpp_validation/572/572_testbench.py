import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def two_unique_nums(nums):
    """Python reference implementation for comparison"""
    return [i for i in nums if nums.count(i) == 1]

@cocotb.test()
async def test_remove_duplicates(dut):
    """Test remove_duplicates module against Python reference implementation"""
    
    # Helper function to set inputs
    def set_inputs(values):
        # Clear all inputs first
        dut.data_in_0.value = 0
        dut.data_in_1.value = 0
        dut.data_in_2.value = 0
        dut.data_in_3.value = 0
        dut.data_in_4.value = 0
        dut.data_in_5.value = 0
        dut.data_in_6.value = 0
        dut.data_in_7.value = 0
        dut.valid_count.value = 0
        
        # Set values
        for i, val in enumerate(values):
            if i == 0:
                dut.data_in_0.value = val
            elif i == 1:
                dut.data_in_1.value = val
            elif i == 2:
                dut.data_in_2.value = val
            elif i == 3:
                dut.data_in_3.value = val
            elif i == 4:
                dut.data_in_4.value = val
            elif i == 5:
                dut.data_in_5.value = val
            elif i == 6:
                dut.data_in_6.value = val
            elif i == 7:
                dut.data_in_7.value = val
        
        dut.valid_count.value = len(values)
    
    # Helper function to get outputs
    def get_outputs():
        return [
            int(dut.unique_0.value),
            int(dut.unique_1.value),
            int(dut.unique_2.value),
            int(dut.unique_3.value),
            int(dut.unique_4.value),
            int(dut.unique_5.value),
            int(dut.unique_6.value),
            int(dut.unique_7.value)
        ], int(dut.unique_count.value)
    
    # Helper function to verify outputs
    def verify_outputs(expected, actual_outputs, actual_count):
        # Extract non-255 values from actual
        actual = [v for v in actual_outputs if v != 255][:actual_count]
        
        if actual_count != len(expected):
            raise TestFailure(f"Count mismatch: expected {len(expected)}, got {actual_count}")
        
        if actual != expected:
            raise TestFailure(f"Values mismatch: expected {expected}, got {actual}")
    
    # Test Case 1: [1,2,3,2,3,4,5] -> [1,4,5]
    print("
Test 1: [1,2,3,2,3,4,5]")
    set_inputs([1,2,3,2,3,4,5])
    await Timer(10, units='ns')
    outputs, count = get_outputs()
    expected = two_unique_nums([1,2,3,2,3,4,5])
    verify_outputs(expected, outputs, count)
    print(f"  Output: {[v for v in outputs if v != 255][:count]}")
    
    # Test Case 2: [1,2,3,2,4,5] -> [1,3,4,5]
    print("
Test 2: [1,2,3,2,4,5]")
    set_inputs([1,2,3,2,4,5])
    await Timer(10, units='ns')
    outputs, count = get_outputs()
    expected = two_unique_nums([1,2,3,2,4,5])
    verify_outputs(expected, outputs, count)
    print(f"  Output: {[v for v in outputs if v != 255][:count]}")
    
    # Test Case 3: [1,2,3,4,5] -> [1,2,3,4,5]
    print("
Test 3: [1,2,3,4,5]")
    set_inputs([1,2,3,4,5])
    await Timer(10, units='ns')
    outputs, count = get_outputs()
    expected = two_unique_nums([1,2,3,4,5])
    verify_outputs(expected, outputs, count)
    print(f"  Output: {[v for v in outputs if v != 255][:count]}")
    
    # Test Case 4: [7,7,7] -> []
    print("
Test 4: [7,7,7]")
    set_inputs([7,7,7])
    await Timer(10, units='ns')
    outputs, count = get_outputs()
    expected = two_unique_nums([7,7,7])
    verify_outputs(expected, outputs, count)
    print(f"  Output: {[v for v in outputs if v != 255][:count]}")
    
    # Test Case 5: [5,3,5,3,1,2,1,2] -> []
    print("
Test 5: [5,3,5,3,1,2,1,2]")
    set_inputs([5,3,5,3,1,2,1,2])
    await Timer(10, units='ns')
    outputs, count = get_outputs()
    expected = two_unique_nums([5,3,5,3,1,2,1,2])
    verify_outputs(expected, outputs, count)
    print(f"  Output: {[v for v in outputs if v != 255][:count]}")
    
    # Test Case 6: [10,20,10,30,40] -> [20,30,40]
    print("
Test 6: [10,20,10,30,40]")
    set_inputs([10,20,10,30,40])
    await Timer(10, units='ns')
    outputs, count = get_outputs()
    expected = two_unique_nums([10,20,10,30,40])
    verify_outputs(expected, outputs, count)
    print(f"  Output: {[v for v in outputs if v != 255][:count]}")
    
    print("
All tests passed! 6/6 tests passed.")
