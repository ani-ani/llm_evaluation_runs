import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_product_even_checker(dut):
    # Test cases with padding to 4 elements (fill with odd numbers)
    test_cases = [
        ([1, 2, 3, 1], 1),   # Original [1,2,3] padded
        ([1, 2, 1, 4], 1),   # Original [1,2,1,4]
        ([1, 1, 1, 1], 0),   # Original [1,1] padded
        ([3, 0, 5, 7], 1),   # Additional edge case: 0 present
        ([255, 254, 1, 3], 1) # Large number (254 even)
    ]
    
    passed = 0
    for arr, expected in test_cases:
        # Convert Python list to LogicArray format
        dut.arr.value = LogicArray("", [8]*4)
        for i,val in enumerate(arr):
            dut.arr.value[i] = val
            
        await Timer(1, units='ns')
        
        if dut.is_even.value == expected:
            passed += 1
            dut._log.info(f"PASS: {arr} => {dut.is_even.value}")
        else:
            dut._log.error(f"FAIL: {arr} => {dut.is_even.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)