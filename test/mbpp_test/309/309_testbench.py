import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_max(dut):
    test_cases = [
        (5, 10, 10),
        (-1, -2, -1),
        (9, 7, 9)
    ]
    passed = 0
    
    for a, b, expected in test_cases:
        dut.a.value = a
        dut.b.value = b
        await Timer(1, units='ns')
        
        if dut.out.value.signed_integer == expected:
            passed += 1
            dut._log.info(f"PASS: max({a}, {b})={expected}")
        else:
            dut._log.error(f"FAIL: max({a}, {b})={dut.out.value.signed_integer}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")