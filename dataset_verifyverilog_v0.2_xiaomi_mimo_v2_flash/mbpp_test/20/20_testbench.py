import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_woodall_check(dut):
    """Test the Woodall number checker module"""
    
    # Woodall numbers in range [0, 65535]
    woodall_numbers = [
        1,      # W_1 = 1*2^1 - 1
        7,      # W_2 = 2*2^2 - 1
        23,     # W_3 = 3*2^3 - 1
        63,     # W_4 = 4*2^4 - 1
        159,    # W_5 = 5*2^5 - 1
        383,    # W_6 = 6*2^6 - 1
        895,    # W_7 = 7*2^7 - 1
        2047,   # W_8 = 8*2^8 - 1
        4607,   # W_9 = 9*2^9 - 1
        10239,  # W_10 = 10*2^10 - 1
        22527,  # W_11 = 11*2^11 - 1
        49151   # W_12 = 12*2^12 - 1
    ]
    
    # Test all Woodall numbers (should return 1)
    passed = 0
    total = 0
    
    dut._log.info("Testing known Woodall numbers...")
    for num in woodall_numbers:
        dut.num.value = num
        await Timer(1, units='ns')
        total += 1
        if dut.is_woodall.value == 1:
            dut._log.info(f"PASS: {num} is correctly identified as Woodall")
            passed += 1
        else:
            dut._log.error(f"FAIL: {num} should be Woodall but got {dut.is_woodall.value}")
    
    # Test the specific examples from the problem
    dut._log.info("
Testing problem examples...")
    
    # Test 1: 383 should be True
    dut.num.value = 383
    await Timer(1, units='ns')
    total += 1
    if dut.is_woodall.value == 1:
        dut._log.info("PASS: is_woodall(383) == True")
        passed += 1
    else:
        dut._log.error(f"FAIL: is_woodall(383) should be True, got {dut.is_woodall.value}")
    
    # Test 2: 254 should be False
    dut.num.value = 254
    await Timer(1, units='ns')
    total += 1
    if dut.is_woodall.value == 0:
        dut._log.info("PASS: is_woodall(254) == False")
        passed += 1
    else:
        dut._log.error(f"FAIL: is_woodall(254) should be False, got {dut.is_woodall.value}")
    
    # Test 3: 200 should be False
    dut.num.value = 200
    await Timer(1, units='ns')
    total += 1
    if dut.is_woodall.value == 0:
        dut._log.info("PASS: is_woodall(200) == False")
        passed += 1
    else:
        dut._log.error(f"FAIL: is_woodall(200) should be False, got {dut.is_woodall.value}")
    
    # Test edge cases
    dut._log.info("
Testing edge cases...")
    
    # Zero should not be Woodall
    dut.num.value = 0
    await Timer(1, units='ns')
    total += 1
    if dut.is_woodall.value == 0:
        dut._log.info("PASS: is_woodall(0) == False")
        passed += 1
    else:
        dut._log.error(f"FAIL: is_woodall(0) should be False, got {dut.is_woodall.value}")
    
    # Test a non-Woodall number near 383
    dut.num.value = 382
    await Timer(1, units='ns')
    total += 1
    if dut.is_woodall.value == 0:
        dut._log.info("PASS: is_woodall(382) == False")
        passed += 1
    else:
        dut._log.error(f"FAIL: is_woodall(382) should be False, got {dut.is_woodall.value}")
    
    # Test a non-Woodall number near 383
    dut.num.value = 384
    await Timer(1, units='ns')
    total += 1
    if dut.is_woodall.value == 0:
        dut._log.info("PASS: is_woodall(384) == False")
        passed += 1
    else:
        dut._log.error(f"FAIL: is_woodall(384) should be False, got {dut.is_woodall.value}")
    
    # Test maximum value
    dut.num.value = 65535
    await Timer(1, units='ns')
    total += 1
    if dut.is_woodall.value == 0:
        dut._log.info("PASS: is_woodall(65535) == False")
        passed += 1
    else:
        dut._log.error(f"FAIL: is_woodall(65535) should be False, got {dut.is_woodall.value}")
    
    # Random non-Woodall numbers
    dut._log.info("
Testing random non-Woodall numbers...")
    for i in range(5):
        num = random.randint(0, 65535)
        while num in woodall_numbers:  # Ensure it's not a Woodall number
            num = random.randint(0, 65535)
        
        dut.num.value = num
        await Timer(1, units='ns')
        total += 1
        if dut.is_woodall.value == 0:
            dut._log.info(f"PASS: is_woodall({num}) == False")
            passed += 1
        else:
            dut._log.error(f"FAIL: is_woodall({num}) should be False, got {dut.is_woodall.value}")
    
    # Summary
    dut._log.info(f"
{'='*50}")
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")
    dut._log.info(f"{'='*50}")
    
    assert passed == total, f"Test failed: {passed}/{total} passed"
