import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_undulating(dut):
    test_cases = [
        (0x12121212, True),   # Original Test 1 expanded to 8 digits
        (0x19911991, False),  # Original Test 2 expanded (failed pattern)
        (0x13131313, True),   # Similar to original Test 3 expanded
        (0x11111111, False),  # All same digits
        (0x12121233, False)   # Broken pattern
    ]
    
    passed = 0
    for num_val, expected in test_cases:
        dut.num.value = num_val
        await Timer(1, units='ns')
        result = dut.is_undulating.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: 0x{num_val:08x} → {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: 0x{num_val:08x} → {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")