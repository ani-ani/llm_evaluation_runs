import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_octagonal(dut):
    """Test cases with both original examples and boundary checks"""
    test_cases = [
        (0, 0),     # Edge case: zeroth octagonal number
        (5, 65),
        (10, 280),
        (15, 645),
        (255, 194565)  # Max 8-bit input test
    ]
    
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')  # Allow combinational logic to settle
        
        result = dut.oct_num.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} => oct_num={result}")
        else:
            dut._log.error(f"FAIL: n={n_val} => got {result}, expected {expected}")
    
    dut._log.info(f"Test summary: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "One or more tests failed"