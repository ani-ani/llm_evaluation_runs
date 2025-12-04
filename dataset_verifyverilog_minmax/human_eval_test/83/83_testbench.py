import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_counter(dut):
    test_cases = [
        (1, 1),   # Original n=1
        (2, 18),  # Original n=2
        (3, 180), # Original n=3
        (4, 1800),
        (5, 18000),
        (15, 180000000000000)  # Scaled max case
    ]
    passed = 0
    
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        result = dut.count.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} => {result}")
        else:
            dut._log.error(f"FAIL: n={n_val} => {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")