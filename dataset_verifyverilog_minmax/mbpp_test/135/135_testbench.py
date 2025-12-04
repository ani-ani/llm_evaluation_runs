import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_hexagonal(dut):
    """Test hexagonal number generator"""
    test_cases = [
        (0, 0),
        (1, 1),
        (5, 45),
        (7, 91),
        (10, 190),
        (16, 496)  # Additional edge case
    ]
    
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        result = dut.result.value.integer
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} => {result}")
        else:
            dut._log.error(f"FAIL: n={n_val} => {result}, expected {expected}")
    
    dut._log.info(f"Summary: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), f"Failed {len(test_cases)-passed} tests"