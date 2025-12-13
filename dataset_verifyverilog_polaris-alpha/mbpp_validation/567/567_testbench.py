import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_sorted_checker(dut):
    # Test cases adapted to 8-element maximum:
    # [element0, element1, ..., element7] as integer values
    test_cases = [
        ([1,2,4,6,8,10,12,14], True),   # Original Test 1 trimmed
        ([1,2,4,6,8,10,14,20], True),   # New sorted case
        ([1,2,4,6,8,10,15,14], False),  # Original Test 3 trimmed & modified
        ([1,3,5,7,9,11,13,15], True),   # New sorted odd numbers
        ([20,17,15,12,10,8,5,2], False), # Completely reversed order
        ([5,5,5,5,5,5,5,5], True),      # All equal elements
        ([1,2,6,4,8,10,12,14], False)   # Early unsorted pair
    ]

    passed = 0
    for lst, expected in test_cases:
        # Pack list into 40-bit value
        flat_value = 0
        for i, val in enumerate(lst):
            flat_value |= (val & 0x1F) << (i*5)
        
        dut.flat_list.value = flat_value
        await Timer(1, units='ns')
        
        if dut.is_sorted.value == expected:
            passed += 1
            dut._log.info(f"PASS: {lst} => {expected}")
        else:
            dut._log.error(f"FAIL: {lst} => {dut.is_sorted.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")