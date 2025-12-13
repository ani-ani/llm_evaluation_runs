import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_checker(dut):
    test_cases = [
        (1234, 1),   # All digits appear once (valid)
        (51241, 0),  # '1' appears twice >1 (invalid)
        (321, 1),    # Expanded to 0321 (leading zero ignored, valid)
        (1000, 0),   # Three '0's >0 (invalid)
        (1123, 0),    # Two '1's >1 (invalid)
        (4444, 1)     # Four '4's (4 <=4 valid)
    ]
    
    passed = 0
    for num, expected in test_cases:
        dut.num.value = num
        await Timer(1, units='ns')
        result = int(dut.valid.value)
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {num} => {expected}")
        else:
            dut._log.error(f"FAIL: {num} got {result}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")
    assert passed == total