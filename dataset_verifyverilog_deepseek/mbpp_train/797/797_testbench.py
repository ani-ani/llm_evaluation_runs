import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_sum_odds(dut):
    test_cases = [
        (2, 5, 8),
        (5, 7, 12),
        (7, 13, 40),
        (1, 1, 1),
        (0, 0, 0),
        (0, 15, 64)
    ]
    passed = 0
    
    for l_val, r_val, expected in test_cases:
        dut.l.value = l_val
        dut.r.value = r_val
        await Timer(1, units='ns')
        result = dut.sum.value.integer
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: l={l_val} r={r_val} => {result}")
        else:
            dut._log.error(f"FAIL: l={l_val} r={r_val} => {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")