import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_quadcopter(dut):
    test_cases = [
        # Inputs                Expected
        ((1, 5, 5, 2), 18),     # Original example 1
        ((0, 1, 0, 0), 8),      # Original example 2
        ((0, 0, 1, 1), 8),      # Diagonal move
        ((100, -100, -100, -100), 406), # Max horizontal test
        ((-100, -100, -100, 100), 406), # Max vertical test
        ((45, -43, 45, -44), 8), # Same x, adjacent y
    ]
    passed = 0
    for (x1, y1, x2, y2), expected in test_cases:
        dut.x1.value = x1
        dut.y1.value = y1
        dut.x2.value = x2
        dut.y2.value = y2
        await Timer(1, units='ns')
        result = dut.path_length.value.integer
        if result == expected:
            passed += 1
        else:
            dut._log.error("Test failed: ({},{})-({},{}) = {}, expected {}".format(x1,y1,x2,y2,result,expected))
    if passed != len(test_cases):
        raise TestFailure(f"{passed}/{len(test_cases)} tests passed")
    dut._log.info(f"All {passed} tests passed")