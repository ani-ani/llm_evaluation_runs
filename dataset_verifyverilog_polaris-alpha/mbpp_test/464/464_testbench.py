import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_dict_check(dut):
    test_cases = [
        # (entries_array, n, expected)
        ([12,12,12,12], 10, 0),   # Original Test 1
        ([12,12,12,12], 12, 1),   # Original Test 2
        ([12,12,12,12], 5, 0),    # Original Test 3
        ([5,5,5,5], 5, 1),        # All match
        ([8,8,7,8], 8, 0),        # One mismatch
        ([0,0,0,0], 0, 1),        # Zero check
        ([255,255,255,255], 255, 1) # Max value check
    ]
    
    passed = 0
    for entries, n_val, expected in test_cases:
        # Pack array into 32-bit vector
        packed = 0
        for i, val in enumerate(entries):
            packed |= (val & 0xFF) << (i*8)
        
        dut.entries.value = packed
        dut.n.value = n_val
        await Timer(1, units='ns')
        
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: {entries} vs {n_val} => {expected}")
        else:
            dut._log.error(f"FAIL: {entries} vs {n_val} => {dut.result.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"