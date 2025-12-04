import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_triplet_counter(dut):
    test_cases = {
        3: 0,
        4: 0,
        5: 1,
        6: 4
    }
    passed = 0
    total = len(test_cases)
    
    for n_val, expected in test_cases.items():
        dut.n.value = n_val
        await Timer(1, units='ns')
        result = dut.count.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} -> {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: n={n_val} got {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total