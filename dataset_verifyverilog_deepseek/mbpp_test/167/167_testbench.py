import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_power_of_two(dut):
    test_cases = [
        (0, 1),     # Original test case
        (5, 8),     # Original test case
        (17, 32),   # Original test case
        (1, 1),     # Edge case: minimum power of two
        (65535, 65536),  # Max input (2^16-1 -> 2^16)
        (256, 256),  # Already power of two
        (32768, 32768),  # Exact power mid-range
        (65536, 65536)  # Should handle max output
    ]
    
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        result = dut.result.value.integer
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} => {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: n={n_val} => {result}, expected {expected}")
    
    # Add random test cases
    for i in range(3):
        n_val = random.randint(2, 60000)
        expected = 1 << (n_val.bit_length())
        
        dut.n.value = n_val
        await Timer(1, units='ns')
        result = dut.result.value.integer
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} => {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: n={n_val} => {result}, expected {expected}")
    
    total = len(test_cases) + 3
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")