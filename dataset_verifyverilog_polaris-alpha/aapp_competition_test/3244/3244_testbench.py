import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestSuccess

@cocotb.test()
async def test_reconstruct(dut):
    test_cases = [
        # Inputs (y0,y1,y2,y3), Expected outputs (x0,x1,x2,x3)
        ((20, 15, 17, 14), (5, 8, 2, 7)),
        ((6, 6, 6, 6), (2, 2, 2, 2)),
        ((9, 9, 12, 12), (2, 2, 5, 5))
    ]
    passed = 0
    for idx, ((y0_in, y1_in, y2_in, y3_in), (x0_exp, x1_exp, x2_exp, x3_exp)) in enumerate(test_cases):
        dut.y0.value = y0_in
        dut.y1.value = y1_in
        dut.y2.value = y2_in
        dut.y3.value = y3_in
        await Timer(1, units='ns')
        
        errors = []
        if dut.x0.value != x0_exp:
            errors.append(f"x0: {dut.x0.value} != {x0_exp}")
        if dut.x1.value != x1_exp:
            errors.append(f"x1: {dut.x1.value} != {x1_exp}")
        if dut.x2.value != x2_exp:
            errors.append(f"x2: {dut.x2.value} != {x2_exp}")
        if dut.x3.value != x3_exp:
            errors.append(f"x3: {dut.x3.value} != {x3_exp}")
        
        if not errors:
            passed += 1
            dut._log.info(f"Test #{idx+1} passed")
        else:
            dut._log.error(f"Test #{idx+1} failed: {', '.join(errors)}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    if passed != len(test_cases):
        raise TestFailure("Some tests failed")
    else:
        raise TestSuccess("All tests passed")