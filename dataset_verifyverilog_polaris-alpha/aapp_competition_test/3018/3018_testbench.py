import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_dice_optimizer(dut):
    test_cases = [
        (3, 9, [5,4,1], 1),
        (4, 13, [2,2,2,2], 3),
        (6, 21, [1,2,3,4,5,6], 0),
        (2, 7, [3,4], 0)
    ]
    passed = 0
    for (K_val, T_val, rolls, expected) in test_cases:
        dut.K.value = K_val
        dut.T.value = T_val
        packed = 0
        for i, val in enumerate(rolls):
            packed |= (val & 0x7) << (i*3)
        dut.first_roll.value = packed
        await Timer(1, units='ns')
        if int(dut.best_r.value) == expected:
            passed += 1
        else:
            dut._log.error("FAIL: K=%d T=%d rolls=%s -> got %d expected %d" % 
                          (K_val, T_val, str(rolls), int(dut.best_r.value), expected))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))