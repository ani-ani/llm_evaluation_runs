import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import random

@cocotb.test()
async def test_fib_mapper(dut):
    test_cases = [
        (3, 1, 1, 4417573500000000001, 4417573500000000000),
        (5, 1, 2, 4417573500000000001, 8835147000000000000),
        (1, 999999, 999999, 9082426500000000001, 9082426500000000000),
        # Known edge cases from original problem
        (2, 2, 1, 8835147000000000001, 4417573500000000000),
        (1, 9, 152265, 3758161500000000001, 5828977500000000000)
    ]
    passed = 0
    fails = []
    for n_val, a_val, d_val, exp_b, exp_e in test_cases:
        dut.n.value = n_val
        dut.a.value = a_val
        dut.d.value = d_val
        await Timer(1, units='ns')
        if int(dut.b.value) == exp_b and int(dut.e.value) == exp_e:
            passed += 1
        else:
            err = f"Input ({n_val},{a_val},{d_val}): Got ({int(dut.b.value)},{int(dut.e.value)}), Expected ({exp_b},{exp_e})"
            fails.append(err)
    
    if fails:
        for msg in fails:
            dut._log.error(msg)
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"