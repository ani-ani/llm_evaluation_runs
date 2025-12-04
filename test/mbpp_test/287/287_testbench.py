import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_sum_of_squares(dut):
    test_cases = [
        (0, 0), 
        (1, 4), 
        (2, 20), 
        (3, 56), 
        (4, 120),
        (10, 1540)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        dut.n.value = n
        await Timer(1, units='ns')
        
        if dut.sum_squares.value == expected:
            dut._log.info(f"PASS: n={n} -> {dut.sum_squares.value} (expected {expected})")
            passed += 1
        else:
            dut._log.error(f"FAIL: n={n} -> {dut.sum_squares.value} but expected {expected}")
    
    dut._log.info(f"Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed} tests"