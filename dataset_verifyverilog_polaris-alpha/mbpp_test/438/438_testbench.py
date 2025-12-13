import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_bidirectional_counter(dut):
    test_cases = [
        # Test 1 (Original Test 1 padded to 8 elements)
        ([0x0506, 0x0102, 0x0605, 0x0901, 0x0605, 0x0201, 0x0000, 0x0000], 3),
        # Test 2 (Original Test 2 padded to 8 elements)
        ([0x0506, 0x0103, 0x0605, 0x0901, 0x0605, 0x0201, 0x0000, 0x0000], 2),
        # Test 3 (Original Test 3 padded to 8 elements)
        ([0x0506, 0x0102, 0x0605, 0x0902, 0x0605, 0x0201, 0x0000, 0x0000], 4),
        # Edge case: Empty pairs
        ([0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000], 0),
        # Full bidirectional grid (6 valid pairs)
        ([0x0102, 0x0201, 0x0103, 0x0301, 0x0203, 0x0302, 0x0000, 0x0000], 6)
    ]
    
    passed = 0
    for idx, (data, expected) in enumerate(test_cases):
        for i in range(8):
            dut.tuples[i].value = data[i]
        await Timer(1, units='ns')
        result = dut.count.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"Test {idx+1} PASS: {result} == {expected}")
        else:
            dut._log.error(f"Test {idx+1} FAIL: Got {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)