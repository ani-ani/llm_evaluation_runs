import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_converter(dut):
    # Reduced test cases (max 16 elements)
    test_cases = [
        ([5,10,7,4,15,3], (5,10,7,4,15,3)),  # Original test 1
        ([2,4,5,6,2,3,4,4,7], (2,4,5,6,2,3,4,4,7)),  # Original test 2
        ([58,44,56], (58,44,56)),  # Original test 3
        ([], ()),  # Added edge case
        ([255, 0], (255, 0))  # Max/min value test
    ]
    
    passed = 0
    for input_list, expected_tuple in test_cases:
        # Pad input to 16 elements
        padded = list(input_list) + [0]*(16-len(input_list))
        
        # Apply inputs
        for i in range(16):
            dut.list_in[i].value = padded[i]
            
        await Timer(1, units='ns')  # Comb logic delay
        
        # Check outputs
        correct = True
        for i in range(len(expected_tuple)):
            if dut.tuple_out[i].value != expected_tuple[i]:
                dut._log.error(f"Mismatch at index {i}: Got {dut.tuple_out[i].value}, expected {expected_tuple[i]}")
                correct = False
        
        if correct:
            passed += 1
            dut._log.info(f"PASS: {input_list} -> {expected_tuple}")
        else:
            dut._log.error(f"FAIL: {input_list} -> {dut.tuple_out.value}")
    
    dut._log.info(f"Summary: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"