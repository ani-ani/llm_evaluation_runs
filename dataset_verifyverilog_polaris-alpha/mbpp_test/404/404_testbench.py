import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_min_finder(dut):
    test_cases = [
        (1, 2, 1),
        (-5, -4, -5),
        (0, 0, 0),
        (-3, 5, -3),
        (127, -128, -128)
    ]
    passed = 0
    
    for a, b, expected in test_cases:
        dut.a.value = a
        dut.b.value = b
        await Timer(1, units='ns')
        result = dut.min_val.value.signed_integer
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: min({a}, {b}) = {result}")
        else:
            dut._log.error(f"FAIL: min({a}, {b}) = {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")