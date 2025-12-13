import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_eulerian(dut):
    # Original test cases + edge cases
    test_cases = [
        (3, 1, 4),
        (4, 1, 11),
        (5, 3, 26),
        (0, 0, 0),   # n=0 test
        (5, 5, 0),   # m=n test
        (2, 0, 1)    # m=0 test
    ]
    passed = 0
    for n_val, m_val, expected in test_cases:
        dut.n.value = n_val
        dut.m.value = m_val
        await Timer(1, units='ns')  # Combinational logic
        result = dut.result.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: a({n_val},{m_val}) = {result}")
        else:
            dut._log.error(f"FAIL: a({n_val},{m_val}) = {result}, expected {expected}")
        assert result == expected, f"Test failed for n={n_val}, m={m_val}"
    
    dut._log.info(f"
SUMMARY: {passed}/{len(test_cases)} tests passed")