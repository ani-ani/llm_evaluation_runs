import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_count(dut):
    test_cases = [
        (0b10100000, 2),   # Original Test 1 (padded to 8 bits)
        (0b00000000, 0),   # Original Test 2 (padded to 8 bits)
        (0b11100000, 3),   # Original Test 3 (padded to 8 bits)
        (0b11111111, 8),   # All Trues
        (0b10101010, 4),   # Alternating pattern
        (0b00010001, 2)    # Sparse Trues
    ]
    
    passed = 0
    for vector, expected in test_cases:
        dut.lst.value = vector
        await Timer(1, units='ns')
        result = dut.count.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {bin(vector)} → {result}")
        else:
            dut._log.error(f"FAIL: {bin(vector)} → {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")