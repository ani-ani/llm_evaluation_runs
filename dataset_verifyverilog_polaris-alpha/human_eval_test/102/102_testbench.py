import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_biggest_even(dut):
    test_cases = [
        (12, 15, 14),
        (13, 12, -1),
        (33, 12354, 12354),
        (5234, 5233, -1),
        (6, 29, 28),
        (27, 10, -1),
        (7, 7, -1),
        (546, 546, 546)
    ]
    
    passed = 0
    for x, y, expected in test_cases:
        dut.x.value = x
        dut.y.value = y
        await Timer(1, units='ns')
        
        result_val = dut.result.value.signed_integer
        if result_val == expected:
            passed += 1
            dut._log.info(f"PASS: x={x}, y={y} => {result_val}")
        else:
            dut._log.error(f"FAIL: x={x}, y={y} => {result_val} (expected {expected})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")