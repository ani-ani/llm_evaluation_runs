import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_xor_odd_pairs(dut):
    # Test case 1: [5,4,7,2,1] + 3 zeros
    test1 = [5,4,7,2,1] + [0]*3  # Expected: 6 odd pairs
    # Test case 2: [7,2,8,1,0,5,11] + 1 zero
    test2 = [7,2,8,1,0,5,11,0]   # Expected: 12 odd pairs
    # Test case 3: [1,2,3] + 5 zeros
    test3 = [1,2,3] + [0]*5      # Expected: 2 odd pairs
    # Edge case: All zeros
    test4 = [0]*8                # Expected: 0
    # Edge case: Max pairs (4 odd, 4 even)
    test5 = [1,3,5,7,2,4,6,8]    # 4*4=16 pairs

    test_cases = [
        (test1, 6),
        (test2, 12),
        (test3, 2),
        (test4, 0),
        (test5, 16)
    ]

    passed = 0
    for data, expected in test_cases:
        # Load input array
        for i in range(8):
            dut.A[i].value = data[i]
        
        await Timer(1, units='ns')  # Combinational delay
        
        result = dut.odd_pair_count.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {data} => {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: {data} => {result} (expected {expected})")
    
    total = len(test_cases)
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed} tests"