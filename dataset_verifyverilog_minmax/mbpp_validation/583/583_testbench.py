import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_catalan(dut):
    test_cases = [
        (0, 1),
        (1, 1),
        (2, 2),
        (7, 429),
        (9, 4862),
        (10, 16796),
        (11, 0)  # out-of-range test
    ]
    passed = 0
    
    for n, expected in test_cases:
        dut.n.value = n
        await Timer(1, units='ns')
        result = dut.catalan.value
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: Catalan(%d) = %d", n, result)
        else:
            dut._log.error(f"FAIL: Catalan(%d) = %d (expected %d)", n, result, expected)
    
    dut._log.info(f"Test summary: {passed}/{len(test_cases)} passed")
    assert passed == len(test_cases)