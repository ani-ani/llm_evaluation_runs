import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_bonbon(dut):
    test_cases = [
        # r  c  a   b  c_in  expected
        (4, 4, 10, 3, 3, 0),
        (4, 4, 6, 5, 5, 1),
        (2, 2, 2, 1, 1, 1),
        (2, 4, 4, 4, 0, 1),
        (2, 4, 5, 3, 0, 0)
    ]
    passed = 0
    for r, c, a, b, c_in, exp in test_cases:
        dut.r.value = r
        dut.c.value = c
        dut.a.value = a
        dut.b.value = b
        dut.c_in.value = c_in
        await Timer(1, units='ns')
        result = dut.possible.value
        if result == exp:
            passed += 1
        else:
            dut._log.error(f"For R={r}, C={c}, a={a}, b={b}, c={c_in}: expected {exp} got {result}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")