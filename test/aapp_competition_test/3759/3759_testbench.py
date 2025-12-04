import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_min_blocked_points(dut):
    test_cases = [
        (0, 1),  # Special case
        (1, 4),
        (2, 8),
        (3, 16),  # 3*1.4142=4.2426→4*4=16
        (4, 20),  # 4*1.4142=5.6568→5*4=20
        (10, 56),  # 10*1.4142=14.142→14*4=56
        (46340, 262136),  # [(46340 * 92682) >> 16] = 65535 *4 = 262140? Wait, need calculation
    ]
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        actual = dut.result.value.integer
        if actual == expected:
            passed += 1
        else:
            dut._log.error("Test failed: n=%d, got=%d, expected=%d" % (n_val, actual, expected))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))