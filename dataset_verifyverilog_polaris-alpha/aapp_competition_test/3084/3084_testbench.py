import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_clock_adjust(dut):
    test_cases = [
        # start_ht, start_hu, start_mt, start_mu, target_ht, target_hu, target_mt, target_mu, expected
        (0, 0, 0, 0, 0, 1, 0, 1, 3),  # 00:00 -> 01:01 (2 steps, 3 displays)
        (0, 0, 0, 8, 0, 0, 0, 0, 3),  # 00:08 -> 00:00 (2 steps)
        (0, 9, 0, 9, 2, 0, 1, 0, 6)   # 09:09 -> 20:10 (5 steps)
    ]

    passed = 0
    for case in test_cases:
        dut.start_ht.value = case[0]
        dut.start_hu.value = case[1]
        dut.start_mt.value = case[2]
        dut.start_mu.value = case[3]
        dut.target_ht.value = case[4]
        dut.target_hu.value = case[5]
        dut.target_mt.value = case[6]
        dut.target_mu.value = case[7]
        await Timer(1, units='ns')
        if dut.count.value == case[8]:
            passed += 1
        else:
            dut._log.error(f"FAIL: {case[0]}{case[1]}:{case[2]}{case[3]} -> {case[4]}{case[5]}:{case[6]}{case[7]} "
                         f"Got {dut.count.value}, Expected {case[8]}")
    if passed != len(test_cases):
        raise TestFailure(f"{passed}/{len(test_cases)} tests passed")
    else:
        dut._log.info(f"{passed}/{len(test_cases)} tests passed")
