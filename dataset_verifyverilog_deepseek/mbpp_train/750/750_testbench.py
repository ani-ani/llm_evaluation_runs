import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_append(dut):
    # Test Cases (input_list, input_size, tuple_elements, expected_output, expected_size)
    test_cases = [
        ([5,6,7], 3, (9,10), [5,6,7,9,10], 5),
        ([6,7,8], 3, (10,11), [6,7,8,10,11], 5),
        ([7,8,9], 3, (11,12), [7,8,9,11,12], 5),
        # Edge cases
        ([], 0, (1,2), [1,2], 2),
        ([10], 1, (20,30), [10,20,30], 3)
    ]

    passed = 0
    for orig_list, size, tup, expected_out, exp_size in test_cases:
        # Pad input_list to 6 elements
        padded_input = orig_list + [0]*(6 - len(orig_list))
        
        # Apply inputs
        dut.input_size.value = size
        for i in range(6):
            dut.input_list[i].value = padded_input[i]
        dut.tuple_element1.value = tup[0]
        dut.tuple_element2.value = tup[1]
        
        await Timer(1, units='ns')
        
        # Check outputs
        size_match = dut.output_size.value == exp_size
        data_match = True
        
        # Only check first (exp_size) elements
        for i in range(exp_size):
            if i < len(expected_out):
                if dut.output_list[i].value != expected_out[i]:
                    data_match = False
                    break
            else:  # Should be zero beyond expected_out length
                if dut.output_list[i].value != 0:
                    data_match = False
                    break
                    
        if size_match and data_match:
            passed += 1
            dut._log.info(f"PASS: Size={size} Tuple={tup} → Output {[dut.output_list[i].value for i in range(exp_size)][:exp_size]}")
        else:
            dut._log.error(f"FAIL: Size={size} Tuple={tup}
  Expected {expected_out} (size={exp_size})
  Got {[dut.output_list[i].value for i in range(8)]} (size={dut.output_size.value})")
    
    dut._log.info(f"RESULT: {passed}/{len(test_cases)} tests passed")