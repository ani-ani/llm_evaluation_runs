import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import random

@cocotb.test()
async def test_remove_odd(dut):
    test_cases = [
        ([1,2,3], [2]),
        ([2,4,6], [2,4,6]),
        ([10,20,3], [10,20]),
        ([1,3,5,7,9,11,13,15], []),  # All odd
        ([8,16,24,0,4,12,20,28], [8,16,24,0,4,12,20,28])  # All even
    ]
    
    passed = 0
    
    for input_list, expected in test_cases:
        # Pad input to 8 elements with zeros
        padded_input = input_list + [0]*(8 - len(input_list))
        
        # Apply input values
        for i in range(8):
            dut.data_in[i].value = padded_input[i]
        
        await Timer(1, units='ns')
        
        # Collect actual outputs
        mask = int(dut.mask_out.value)
        actual = [dut.data_in[i].value for i in range(8) if (mask >> (7-i)) & 1]
        
        # Compare with expected
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {input_list} => {expected}")
        else:
            dut._log.error(f"FAIL: {input_list} => {actual}, expected {expected}")
    
    # Random test case
    random_input = [random.randint(0, 255) for _ in range(8)]
    expected_random = [x for x in random_input if x % 2 == 0]
    
    for i in range(8):
        dut.data_in[i].value = random_input[i]
    
    await Timer(1, units='ns')
    mask = int(dut.mask_out.value)
    actual_random = [dut.data_in[i].value for i in range(8) if (mask >> (7-i)) & 1]
    
    if actual_random == expected_random:
        passed += 1
        dut._log.info(f"PASS: Random test passed")
    else:
        dut._log.error(f"FAIL: Random test {random_input} => {actual_random}, expected {expected_random}")
    
    total_tests = len(test_cases) + 1
    dut._log.info(f"{passed}/{total_tests} tests passed")