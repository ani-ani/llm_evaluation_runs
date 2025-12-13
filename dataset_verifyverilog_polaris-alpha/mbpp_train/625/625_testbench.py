import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_swapper(dut):
    # Test cases: (input_list, array_size, expected_output)
    test_cases = [
        ([1,2,3], 3, [3,2,1]),
        ([1,2,3,4,4], 5, [4,2,3,4,1]),
        ([4,5,6], 3, [6,5,4]),
        ([10], 1, [10]),  # Single element
        ([], 0, [])  # Empty (output irrelevant)
    ]

    passed = 0
    total = len(test_cases)

    for idx, (in_list, size, exp_out) in enumerate(test_cases):
        # Pad input to 8 elements with zeros
        padded_in = list(in_list) + [0]*(8 - len(in_list))
        padded_exp = list(exp_out) + [0]*(8 - len(exp_out))
        
        # Apply inputs
        dut.array_size.value = size
        for i in range(8):
            dut.arr_in[i].value = padded_in[i]
        
        # Allow combinational logic to settle
        await Timer(1, units='ns')
        
        # Check outputs
        valid = True
        errors = []
        
        # Only check up to array_size elements
        check_range = range(size if size <= 8 else 8)
        
        for i in check_range:
            actual = dut.arr_out[i].value
            expected = padded_exp[i]
            
            if int(actual) != expected:
                errors.append(f"Index {i}: {actual} != {expected}")
                valid = False
        
        if valid:
            passed += 1
            dut._log.info(f"Test {idx+1} PASSED")
        else:
            dut._log.error(f"Test {idx+1} FAILED: Size={size} Input={in_list}
Errors: {', '.join(errors)}")
    
    # Empty array case closure - don't check outputs
    await Timer(1, units='ns')
    
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")
    assert passed == total, f"{passed}/{total} tests passed"