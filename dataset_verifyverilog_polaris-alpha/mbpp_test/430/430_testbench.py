import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_directrix(dut):
    test_cases = [
        (5, 3, 2, -198),
        (9, 8, 4, -2336),
        (2, 4, 6, -130)
    ]
    passed = 0

    for a_val, b_val, c_val, expected in test_cases:
        dut.a.value = a_val
        dut.b.value = b_val
        dut.c.value = c_val
        await Timer(1, units='ns')
        
        result = dut.directrix.value.signed_integer
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: ({a_val}, {b_val}, {c_val}) => {result}")
        else:
            dut._log.error(f"FAIL: ({a_val}, {b_val}, {c_val}) => {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")