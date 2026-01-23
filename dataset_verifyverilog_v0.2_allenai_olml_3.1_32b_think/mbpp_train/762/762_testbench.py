import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_month_30days_check(dut):
    """Test month 30 days check module"""
    
    # Test case 1: Month 6 has 30 days (should return True/1)
    dut.month.value = 6
    await Timer(10, units='ns')
    assert dut.is_30_days.value == 1, f"Test 1 failed: month 6 should be 30 days, got {dut.is_30_days.value}"
    print("Test 1 passed: month 6 is 30 days")
    
    # Test case 2: Month 2 has 28/29 days (should return False/0)
    dut.month.value = 2
    await Timer(10, units='ns')
    assert dut.is_30_days.value == 0, f"Test 2 failed: month 2 should not be 30 days, got {dut.is_30_days.value}"
    print("Test 2 passed: month 2 is not 30 days")
    
    # Test case 3: Month 12 has 31 days (should return False/0)
    dut.month.value = 12
    await Timer(10, units='ns')
    assert dut.is_30_days.value == 0, f"Test 3 failed: month 12 should not be 30 days, got {dut.is_30_days.value}"
    print("Test 3 passed: month 12 is not 30 days")
    
    # Additional test cases for completeness
    # All 30-day months: 4, 6, 9, 11
    for month in [4, 6, 9, 11]:
        dut.month.value = month
        await Timer(10, units='ns')
        assert dut.is_30_days.value == 1, f"Failed: month {month} should be 30 days"
        print(f"Additional test passed: month {month} is 30 days")
    
    # All non-30-day months: 1, 2, 3, 5, 7, 8, 10, 12
    for month in [1, 2, 3, 5, 7, 8, 10, 12]:
        dut.month.value = month
        await Timer(10, units='ns')
        assert dut.is_30_days.value == 0, f"Failed: month {month} should not be 30 days"
        print(f"Additional test passed: month {month} is not 30 days")
    
    print("All 12 tests passed!")
