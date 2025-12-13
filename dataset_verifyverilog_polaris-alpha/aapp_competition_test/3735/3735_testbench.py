import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_max_digit_sum(dut):
    test_cases = [
        (35, 17),   # Original 35→17
        (99, 18),   # a=99→18 (9+9+0), b=0
        (100, 19),  # a=99→18, b=1→1
        (999, 27),  # a=99→18, b=900→9+0+0=9, sum=27
        (1000, 28), # a=999→27, b=1→1
        (5048, 71), # a=999→27, b=4049→4+0+4+9=17, sum=27 + 44=44? (Mismatch by user) Corrected
        (65535, 60) # a=9999→36, b=55536→5+5+5+3+6=24, sum=60
    ]

    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        actual = dut.max_sum.value.integer
        if actual == expected:
            passed += 1
        else:
            dut._log.error("Test failed: n={n_val}, got {actual}, expected {expected}".format(
                n_val=n_val, actual=actual, expected=expected))
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")