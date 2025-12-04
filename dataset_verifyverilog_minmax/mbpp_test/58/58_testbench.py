import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
@cocotb.test()
async def test_sign_checker(dut):
    test_cases = [
        # (x, y, expected)
        (1, -2, True),   # Test 1 original
        (3, 2, False),   # Test 2 original
        (-10, -10, False),# Test 3 original
        (-2, 2, True)    # Test 4 original
    ]
    passed = 0
    for x_val, y_val, expected in test_cases:
        # Convert to 8-bit signed representation
        dut.x.value = LogicArray(x_val, range=[7,0]).integer
        dut.y.value = LogicArray(y_val, range=[7,0]).integer
        await Timer(1, units='ns')
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: {x_val}, {y_val} → {expected}")
        else:
            dut._log.error(f"FAIL: {x_val}, {y_val} → {dut.result.value}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")