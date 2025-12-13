import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_max_length(dut):
    test_cases = [
        # Original Test 1 adapted: [6,3,7] + padding
        ([6, 3, 7, 0], 7),
        # Original Test 2 adapted: [1,2,3] + padding
        ([1, 2, 3, 0], 3),
        # Original Test 3 adapted: [5,3,4] + padding
        ([5, 3, 4, 0], 5),
        # Edge case: all zeros
        ([0, 0, 0, 0], 0),
        # Max value test
        ([15, 12, 9, 14], 15)
    ]
    passed = 0
    for lengths, expected in test_cases:
        dut.word0_len.value = lengths[0]
        dut.word1_len.value = lengths[1]
        dut.word2_len.value = lengths[2]
        dut.word3_len.value = lengths[3]
        await Timer(1, units='ns')
        result = dut.max_length.value
        if int(result) == expected:
            passed += 1
            dut._log.info(f"PASS: Inputs {lengths} => Max {expected}")
        else:
            dut._log.error(f"FAIL: Inputs {lengths} => Got {result}, Expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")