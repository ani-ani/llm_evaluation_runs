import cocotb
from cocotb.triggers import Timer
from math import comb

@cocotb.test()
async def test_binomial(dut):
    test_cases = [
        (1, 1),
        (3, 15),
        (4, 56),
        (2, 4),   # C(4,1)=4
        (5, 210)  # C(10,4)=210
    ]
    
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        result = dut.result.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} -> {result}")
        else:
            dut._log.error(f"FAIL: n={n_val} got {result}, expected {expected} (math.comb({2*n_val}, {n_val-1})={comb(2*n_val, n_val-1)})")
    
    # Test invalid n=0 guard
    dut.n.value = 0
    await Timer(1, units='ns')
    invalid_result = dut.result.value.integer
    if invalid_result != 0:
        dut._log.error(f"FAIL: n=0 got {invalid_result}, should output 0")
    else:
        passed += 1
        dut._log.info(f"PASS: n=0 -> 0")
    
    total_tests = len(test_cases) + 1
    dut._log.info(f"{passed}/{total_tests} tests passed")
    assert passed == total_tests