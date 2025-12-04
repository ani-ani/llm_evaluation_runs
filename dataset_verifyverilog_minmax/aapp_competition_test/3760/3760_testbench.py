import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_max_rectangle(dut):
    test_cases = [
        # Original tests scaled down
        (9, 9, 5, 5, 2, 1, (1, 3, 9, 7)),
        (100, 100, 52, 50, 46, 56, (17, 8, 86, 92)),
        # Edge cases
        (70, 10, 20, 5, 5, 3, (12, 0, 27, 9)),   
        (200, 150, 100, 75, 100, 100, (50, 25, 150, 125)),  # 1:1 ratio
        (50, 200, 25, 100, 50, 100, (0, 0, 50, 100)),       # max width/height
        # Extreme point positions
        (255, 255, 0, 0, 100, 100, (0, 0, 100, 100))
    ]
    passed = 0
    for case in test_cases:
        n, m, x_val, y_val, a_val, b_val, expected = case
        dut.n.value = n
        dut.m.value = m
        dut.x.value = x_val
        dut.y.value = y_val
        dut.a.value = a_val
        dut.b.value = b_val
        await Timer(1, units='ns')
        
        result = (int(dut.x1.value), int(dut.y1.value),
                   int(dut.x2.value), int(dut.y2.value))
        
        if result == expected:
            passed += 1
        else:
            dut._log.error(f"FAIL: Input {case[:6]} => Result {result}, Expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")