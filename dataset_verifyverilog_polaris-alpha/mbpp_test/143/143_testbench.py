import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_count_lists(dut):
    # Test cases: (is_list, expected_count)
    test_cases = [
        (0b0011, 2),  # Test 1: 2 lists
        (0b0111, 3),  # Test 2: 3 lists
        (0b0001, 1),  # Test 3: 1 list
        (0b1010, 2),  # Additional: mixed list/non-list
        (0b0000, 0)   # Edge case: no lists
    ]
    
    passed = 0
    for is_list, expected in test_cases:
        dut.is_list.value = is_list
        dut.elements.value = 0  # Actual data unused
        await Timer(1, units='ns')
        count = dut.list_count.value.integer
        if count == expected:
            passed += 1
            dut._log.info(f"PASS: {is_list:#06b} -> {count}")
        else:
            dut._log.error(f"FAIL: {is_list:#06b} got {count}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"RESULT: {passed}/{total} tests passed")