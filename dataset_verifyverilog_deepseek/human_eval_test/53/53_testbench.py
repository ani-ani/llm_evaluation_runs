import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_adder(dut):
    """Test addition of scaled numbers"""
    test_cases = [
        (0, 1, 1),
        (1, 0, 1),
        (2, 3, 5),
        (5, 7, 12),
        (7, 5, 12),
        (1000, 1000, 2000)
    ]

    passed = 0
    for (a_val, b_val, expected) in test_cases:
        dut.a.value = a_val
        dut.b.value = b_val
        await Timer(1, units='ns')  # Allow combinational logic to settle
        
        actual = dut.sum.value
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {a_val} + {b_val} = {actual}")
        else:
            dut._log.error(f"FAIL: {a_val} + {b_val} = {actual} (expected {expected})")
    
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)