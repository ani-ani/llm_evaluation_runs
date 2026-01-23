import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_dog_age_calculator(dut):
    """Test the dog age calculator with various inputs"""
    
    # Test Case 1: h_age = 12, expected = 61
    # Logic: 12 > 2 -> 21 + (12-2)*4 = 21 + 40 = 61
    # Expected fixed-point: 61 * 65536 = 3997696 = 0x003D0000
    dut.human_age.value = 12
    await Timer(10, units='ns')
    result = dut.dog_age.value
    expected = 61 * 65536
    if int(result) != expected:
        raise TestFailure(f"Test 1 failed: h_age=12. Expected {expected}, got {int(result)}")
    print(f"Test 1 passed: h_age=12, result={int(result)}, expected={expected}")

    # Test Case 2: h_age = 15, expected = 73
    # Logic: 15 > 2 -> 21 + (15-2)*4 = 21 + 52 = 73
    # Expected: 73 * 65536 = 4784128 = 0x00490000
    dut.human_age.value = 15
    await Timer(10, units='ns')
    result = dut.dog_age.value
    expected = 73 * 65536
    if int(result) != expected:
        raise TestFailure(f"Test 2 failed: h_age=15. Expected {expected}, got {int(result)}")
    print(f"Test 2 passed: h_age=15, result={int(result)}, expected={expected}")

    # Test Case 3: h_age = 24, expected = 109
    # Logic: 24 > 2 -> 21 + (24-2)*4 = 21 + 88 = 109
    # Expected: 109 * 65536 = 7143424 = 0x006D0000
    dut.human_age.value = 24
    await Timer(10, units='ns')
    result = dut.dog_age.value
    expected = 109 * 65536
    if int(result) != expected:
        raise TestFailure(f"Test 3 failed: h_age=24. Expected {expected}, got {int(result)}")
    print(f"Test 3 passed: h_age=24, result={int(result)}, expected={expected}")

    # Test Case 4: Edge case h_age = 2, expected = 2 * 10.5 = 21
    # Expected: 21 * 65536 = 1376256 = 0x00150000
    dut.human_age.value = 2
    await Timer(10, units='ns')
    result = dut.dog_age.value
    expected = 21 * 65536
    if int(result) != expected:
        raise TestFailure(f"Test 4 failed: h_age=2. Expected {expected}, got {int(result)}")
    print(f"Test 4 passed: h_age=2, result={int(result)}, expected={expected}")

    # Test Case 5: Edge case h_age = 1, expected = 1 * 10.5 = 10.5
    # Expected: 10.5 * 65536 = 688128 = 0x000A8000
    dut.human_age.value = 1
    await Timer(10, units='ns')
    result = dut.dog_age.value
    expected = int(10.5 * 65536)
    if int(result) != expected:
        raise TestFailure(f"Test 5 failed: h_age=1. Expected {expected}, got {int(result)}")
    print(f"Test 5 passed: h_age=1, result={int(result)}, expected={expected}")

    print("All 5 tests passed.")