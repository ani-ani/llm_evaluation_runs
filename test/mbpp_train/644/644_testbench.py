import cocotb
from cocotb.triggers import Timer
@cocotb.test()
async def test_reverse(dut):
    test_cases = [
        # Format: (k_value, input_array, expected_output)
        (4, [1,2,3,4,5,6,0,0], [4,3,2,1,5,6,0,0]),  # Original Test 1
        (2, [4,5,6,7,0,0,0,0], [5,4,6,7,0,0,0,0]),  # Original Test 2
        (3, [9,8,7,6,5,0,0,0], [7,8,9,6,5,0,0,0]),  # Original Test 3
        (0, [1,2,3,4,5,6,7,8], [1,2,3,4,5,6,7,8]),  # Edge case: no reversal
        (8, [1,2,3,4,5,6,7,8], [8,7,6,5,4,3,2,1])   # Edge case: full reversal
    ]
    passed = 0
    for k_val, arr_in, expected in test_cases:
        dut.k.value = k_val
        dut.arr_in.value = arr_in
        await Timer(1, units='ns')
        result = dut.arr_out.value
        if list(result) == expected:
            passed += 1
            dut._log.info(f"PASS: k={k_val}, input={arr_in} => {expected}")
        else:
            dut._log.error(f"FAIL: k={k_val}, input={arr_in} => {result}, expected {expected}")
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} passed")