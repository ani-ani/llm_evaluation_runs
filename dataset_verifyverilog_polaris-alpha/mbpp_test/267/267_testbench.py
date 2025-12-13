import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_square_sum(dut):
    test_cases = [
        (1, 1),
        (2, 10),
        (3, 35),
        (4, 84),
        (5, 165)
    ]
    
    passed = 0
    
    for n_val, expected_sum in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        
        if int(dut.sum.value) == expected_sum:
            passed += 1
            dut._log.info(f"PASS: n={n_val} => sum={expected_sum}")
        else:
            dut._log.error(f"FAIL: n={n_val} => got {int(dut.sum.value)}, expected {expected_sum}")
    
    random_cases = [(random.randint(6,31), (n * (4*n*n - 1) // 3)) for n in random.sample(range(6,31), 2)]
    
    for n_val, expected_sum in random_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        
        if int(dut.sum.value) == expected_sum:
            passed += 1
            dut._log.info(f"PASS: n={n_val} => sum={expected_sum}")
        else:
            dut._log.error(f"FAIL: n={n_val} => got {int(dut.sum.value)}, expected {expected_sum}")
    
    dut._log.info(f"{passed}/{len(test_cases)+len(random_cases)} tests passed")