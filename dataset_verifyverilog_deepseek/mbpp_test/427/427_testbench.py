import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_date_converter(dut):
    test_cases = [
        (2026, 1, 2, (2 << 16) | (1 << 12) | 2026),
        (2020, 11, 13, (13 << 16) | (11 << 12) | 2020),
        (2021, 4, 26, (26 << 16) | (4 << 12) | 2021)
    ]

    passed = 0
    for year, month, day, expected in test_cases:
        dut.year.value = year
        dut.month.value = month
        dut.day.value = day
        await Timer(1, units='ns')
        
        result = dut.formatted_date.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {year}-{month}-{day} => {hex(result)}")
        else:
            dut._log.error(f"FAIL: {year}-{month}-{day} => {hex(result)}, expected {hex(expected)}")
    
    # Test edge cases
    edge_cases = [
        (0, 1, 1, (1 << 16) | (1 << 12) | 0),        # Minimum year
        (4095, 12, 31, (31 << 16) | (12 << 12) | 4095) # Maximums
    ]
    
    for year, month, day, expected in edge_cases:
        dut.year.value = year
        dut.month.value = month
        dut.day.value = day
        await Timer(1, units='ns')
        
        result = dut.formatted_date.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: Edge case {year}-{month}-{day} => {hex(result)}")
        else:
            dut._log.error(f"FAIL: Edge case {year}-{month}-{day} => {hex(result)}, expected {hex(expected)}")
    
    total = len(test_cases) + len(edge_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total