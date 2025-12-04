import cocotb
from cocotb.triggers import Timer
@cocotb.test()
async def test_majority(dut):
    test_cases = [
        # Test 1: Majority exists
        ([1, 2, 3, 3, 3, 3, 10, 0], 7, 3, True),
        # Test 2: Not majority (only 3/8)
        ([1, 1, 2, 4, 4, 4, 6, 6], 8, 4, False),
        # Test 3: Majority exists
        ([1, 1, 1, 2, 2, 0, 0, 0], 5, 1, True),
        # Test 4: Not majority (2/4)
        ([1, 1, 2, 2, 0, 0, 0, 0], 4, 1, False)
    ]
    passed = 0
    for arr, n, x, expected in test_cases:
        for i in range(8):
            dut.arr[i].value = arr[i]
        dut.n.value = n
        dut.x.value = x
        await Timer(1, units='ns')
        result = dut.is_majority.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {arr[:n]} {x} -> {expected}")
        else:
            dut._log.error(f"FAIL: {arr[:n]} {x} -> got {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")