import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_intersperse(dut):
    """Test cases adapted from original Python"""
    
    # Test Cases (input_list, delimeter, expected_output)
    test_cases = [
        ([],        7,  [],                0),  # Original empty case
        ([5,6,3,2],8,  [5,8,6,8,3,8,2],  7),  # Original 4-element case
        ([2,2,2],  2,  [2,2,2,2,2],      5),  # Original 3-element case
        ([10],      0,  [10],             1),  # New edge case: single element
        ([255,0],  128,[255,128,0],       3)   # New edge case: max 8-bit values
    ]
    
    passed = 0
    for idx, (in_list, delim, exp_list, exp_len) in enumerate(test_cases):
        # Set inputs
        dut.length.value = len(in_list)
        dut.delimeter.value = delim
        
        # Pad input list with zeros
        padded_in = in_list + [0]*(4 - len(in_list))
        for i in range(4):
            dut.input_array[i].value = padded_in[i]
        
        # Wait for comb logic
        await Timer(1, units='ns')
        
        # Verify output length
        if dut.output_length.value != exp_len:
            dut._log.error(f"TEST {idx}: Bad length. Got {dut.output_length.value}, expected {exp_len}")
            continue
        
        # Verify valid elements
        match = True
        for i in range(exp_len):
            val = dut.result_array[i].value
            exp = exp_list[i] if i < len(exp_list) else 0
            if val != exp:
                dut._log.error(f"TEST {idx}: Bad val at pos {i}. Got {val}, expected {exp}")
                match = False
                break
        
        if match:
            passed += 1
            dut._log.info(f"TEST {idx} passed")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed}/{total} tests"