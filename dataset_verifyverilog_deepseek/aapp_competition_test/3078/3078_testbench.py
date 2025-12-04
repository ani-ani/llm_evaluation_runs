import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_subsequence(dut):
    test_cases = [
        # S, array, expected results
        (9, [1,1,10,1,9,0,0,0], [2,0,0,2,0,0,0,0]),
        (10000, [1,1,1,1,1,10000,0,0], [4,4,2,2,0,0,0,0]),
        (3, [1,1,1,1,1,1,1,1], [6,6,6,4,4,2,2,0]),
        (5, [2,3,1,4,0,0,0,0], [4,0,0,0,0,0,0,0])
    ]
    passed = 0
    for idx, (s_val, arr, expected) in enumerate(test_cases):
        dut.S.value = s_val
        for i in range(8):
            dut.A[i].value = arr[i]
        await Timer(1, units='ns')
        results = [dut.result[i].value for i in range(8)]
        if results == expected:
            passed += 1
        else:
            dut._log.error("Test %d failed: S=%d, Array=%s" % (idx+1, s_val, arr))
            dut._log.error("Got: %s, Expected: %s" % (results, expected))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))