import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_even_binomial(dut):
    test_cases = [
        (1, 1),   # 2^0 = 1
        (2, 2),   # 2^1 = 2
        (4, 8),   # 2^3 = 8
        (6, 32),  # 2^5 = 32
        (8, 128), # 2^7 = 128
        (15, 16384) # 2^14 = 16384
    ]
    
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        result = dut.sum.value.integer
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} => {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: n={n_val} => {result} (expected {expected})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)