import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_truncate_fixed(dut):
    # Convert float to Q16.16 format (multiply by 65536)
    def to_q16(x):
        return int(x * (1 << 16))
    
    # Expected fractional part in Q16.16 format
    def expected_frac(x):
        frac = round(x - math.floor(x), 4)  # Match test precision
        return int(frac * (1 << 16))

    test_cases = [
        (3.5, 	0x00038000),
        (1.33, 	0x0151EB85),
        (123.456, 0x74BC6A7F)
    ]
    
    passed = 0
    for val, q_val in test_cases:
        dut.number.value = to_q16(val)
        await Timer(1, units='ns')
        
        expected = expected_frac(val)
        result = dut.decimal.value
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {val} → {hex(result)} (expected {hex(expected)})")
        else:
            dut._log.error(f"FAIL: {val} → {hex(result)}, expected {hex(expected)}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)