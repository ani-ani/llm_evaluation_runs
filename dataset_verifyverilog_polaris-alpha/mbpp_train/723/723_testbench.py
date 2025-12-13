import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_counter(dut):
    # Adapted test cases (max 8 elements)
    test_cases = [
        # Original Test 1 (8 elements)
        ([1, 2, 3, 4, 5, 6, 7, 8], [2, 2, 3, 1, 2, 6, 7, 9], 4),
        
        # Test 2 adapted: First 8 elements
        ([0, 1, 2, -1, -5, 6, 0, -3], [2, 1, 2, -1, -5, 6, 4, -3], 5),
        
        # Test 3 adapted: First 8 elements (pad shorter list)
        ([2, 4, -6, -9, 11, -12, 14, -5], [2, 1, 2, -1, -5, 6, 4, -3], 1),
        
        # Test 4 adapted: Pad to 8 elements
        ([0, 1, 1, 2, 99, 99, 99, 99], [0, 1, 2, 2, 99, 99, 99, 99], 2)
    ]
    
    passed = 0
    for l1, l2, expected in test_cases:
        # Apply test vectors
        for i in range(8):
            dut.list1[i].value = l1[i] if i < len(l1) else 99
            dut.list2[i].value = l2[i] if i < len(l2) else 98  # Ensure padding doesn't match
        
        await Timer(1, units='ns')
        
        if dut.count.value == expected:
            passed += 1
            dut._log.info(f"PASS: {l1[:8]} vs {l2[:8]} → {int(dut.count.value)}")
        else:
            dut._log.error(f"FAIL: Expected {expected} Got {int(dut.count.value)} for inputs {l1} vs {l2}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)