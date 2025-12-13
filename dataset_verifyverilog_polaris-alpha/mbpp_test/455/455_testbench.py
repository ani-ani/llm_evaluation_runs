import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_month_check(dut):
    test_cases = [
        (1, True),   # January
        (2, False),  # February
        (3, True),   # March
        (4, False),  # April
        (5, True),   # May
        (6, False),  # June
        (7, True),   # July
        (8, True),   # August
        (9, False),  # September
        (10, True),  # October
        (11, False), # November
        (12, True)   # December
    ]
    
    passed = 0
    total = len(test_cases)
    
    for month, expected in test_cases:
        dut.monthnum.value = month
        await Timer(1, units='ns')
        result = int(dut.has_31_days.value)
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: Month {month} {'has' if expected else 'doesn't have'} 31 days")
        else:
            dut._log.error(f"FAIL: Month {month} - expected {expected}, got {result}")
    
    dut._log.info(f"{passed}/{total} tests passed")