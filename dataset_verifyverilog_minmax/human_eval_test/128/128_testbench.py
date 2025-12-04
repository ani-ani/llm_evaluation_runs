import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_prod_signs(dut):
    test_cases = [
        # Format: (array_length, arr_values, expected_result, expected_valid)
        (4, [1, 2, 2, -4, 0,0,0,0], -9, 1),    # Original [1,2,2,-4]
        (2, [0, 1, 0,0,0,0,0,0], 0, 1),        # Original [0,1]
        (7, [1,1,1,2,3,-1,1,0], -10, 1),       # Original [1,1,1,2,3,-1,1]
        (0, [0]*8, 0, 0),                      # Empty array case
        (7, [2,4,1,2,-1,-1,9,0], 20, 1),       # Original [2,4,1,2,-1,-1,9]
        (4, [-1,1,-1,1,0,0,0,0], 4, 1),        # Original [-1,1,-1,1]
        (4, [-1,1,1,1,0,0,0,0], -4, 1),        # Original [-1,1,1,1]
        (4, [-1,1,1,0,0,0,0,0], 0, 1)          # Original [-1,1,1,0]
    ]

    passed = 0
    for idx, (length, arr_in, exp_result, exp_valid) in enumerate(test_cases):
        dut.array_length.value = length
        for i in range(8):
            dut.arr[i].value = arr_in[i]
        await Timer(1, units='ns')

        if exp_valid:
            if dut.valid.value != 1:
                dut._log.error(f"Test {idx} FAIL: valid should be 1 for non-empty array")
            elif dut.result.value == exp_result:
                passed += 1
                dut._log.info(f"Test {idx} PASS: {arr_in[:length]} → {dut.result.value}")
            else:
                dut._log.error(f"Test {idx} FAIL: {arr_in[:length]} → {dut.result.value} (expected {exp_result})")
        else:
            if dut.valid.value != 0:
                dut._log.error(f"Test {idx} FAIL: valid should be 0 for empty array")
            else:
                passed += 1
                dut._log.info(f"Test {idx} PASS: empty array handled correctly")

    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, f"{total-passed} test(s) failed"