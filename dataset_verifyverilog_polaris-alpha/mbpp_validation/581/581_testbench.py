import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_pyramid(dut):
    test_cases = [
        (3, 4, 33),
        (4, 5, 56),
        (1, 2, 5),
        (15, 15, 675)  # Added edge case
    ]
    passed = 0
    
    for b, s, expected in test_cases:
        dut.b.value = b
        dut.s.value = s
        await Timer(1, units='ns')
        
        if dut.area.value == expected:
            passed += 1
            dut._log.info(f"PASS: b={b}, s={s} => {dut.area.value}")
        else:
            dut._log.error(f"FAIL: b={b}, s={s} => {dut.area.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")