import cocotb
from cocotb.triggers import Timer
from cocotb.types import Range

@cocotb.test()
async def test_min_of_three(dut):
    test_cases = [
        (10, 20, 0, 0),
        (19, 15, 18, 15),
        ( -10, -20, -30, -30)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (a, b, c, expected) in enumerate(test_cases):
        dut.a.value = a & 0xFF  # Convert to signed 8-bit
        dut.b.value = b & 0xFF
        dut.c.value = c & 0xFF
        await Timer(1, units='ns')
        
        result = dut.min_val.value.signed_integer
        is_correct = result == expected
        
        if is_correct:
            passed += 1
            dut._log.info(f"Test {idx+1}: PASS: min({a}, {b}, {c}) = {result}")
        else:
            dut._log.error(f"Test {idx+1}: FAIL: min({a}, {b}, {c}) = {result} (expected {expected})")
    
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")