import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_elementwise_sub(dut):
    test_cases = [
        # Format: (a_list, b_list, valid_entries, expected_results)
        # Test 1: Original 3 elements
        ([1, 2, 3, 0], [4, 5, 6, 0], 3, [-3, -3, -3, 0]),
        # Test 2: Original 2 elements
        ([1, 2, 0, 0], [3, 4, 0, 0], 2, [-2, -2, 0, 0]),
        # Test 3: Original test scaled
        ([90, 120, 0, 0], [50, 70, 0, 0], 2, [40, 50, 0, 0]),
        # Test 4: 4 elements with negative
        ([100, 75, -20, 10], [50, 100, -15, 5], 0, [50, -25, -5, 5])
    ]

    passed = 0
    for a_vals, b_vals, val_en, expected in test_cases:
        # Assign inputs
        for i in range(4):
            dut.a[i].value = a_vals[i] & 0xFF  # Convert to signed
            dut.b[i].value = b_vals[i] & 0xFF
        dut.valid_entries.value = val_en
        
        await Timer(1, units='ns')
        
        # Determine valid positions
        valid_count = 4 if val_en == 0 else val_en
        
        # Check results
        correct = True
        for i in range(4):
            actual = dut.diff[i].value.signed_integer
            exp = expected[i] if i < valid_count else 0
            
            if actual != exp:
                dut._log.error(f"Mismatch at pos {i}: {actual} != {exp}")
                correct = False
        
        if correct:
            passed += 1
            dut._log.info(f"PASS: {a_vals[:valid_count]} - {b_vals[:valid_count]} = {expected[:valid_count]}")
        else:
            dut._log.error(f"FAIL: {a_vals} - {b_vals} (val_en={val_en})
  Expected: {expected}
  Got: {[dut.diff[i].value.signed_integer for i in range(4)]}")
    
    dut._log.info(f"SUMMARY: {passed}/{len(test_cases)} tests passed")