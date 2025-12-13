import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_count_element(dut):
    # Test cases adapted from original Python
    # Format: (tuple elements (12x4-bit), target, expected_count)
    #         stored as (64-bit flattened array, 4-bit target, 4-bit expected)
    
    # Test 1 (No matches): Searching for 4 (0b0100)
    # Original: (10,8,5,2,10,15,10,8,5,8,8,2)
    test1_array = (10<<0)|(8<<4)|(5<<8)|(2<<12)|(10<<16)|(15<<20)|(10<<24)|(8<<28)|(5<<32)|(8<<36)|(8<<40)|(2<<44)
    # Test 2 (3 matches of 10):
    test2_array = test1_array
    # Test 3 (4 matches of 8):
    test3_array = test1_array
    # Edge case (all matches)
    test4_array = (5<<0)|(5<<4)|(5<<8)|(5<<12)|(5<<16)|(5<<20)|(5<<24)|(5<<28)|(5<<32)|(5<<36)|(5<<40)|(5<<44)
    
    test_cases = [
        (test1_array, 4, 0),   # Original Test 1
        (test1_array, 10, 3),  # Original Test 2
        (test1_array, 8, 4),   # Original Test 3
        (test4_array, 5, 12),  # All elements match
        (test4_array, 0, 0)    # None match
    ]
    
    passed = 0
    for tup_data, target, expected in test_cases:
        dut.array_data.value = tup_data
        dut.target.value = target
        await Timer(1, units='ns')
        result = dut.count.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: Count of {target} in tuple: {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: Count of {target} got {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")