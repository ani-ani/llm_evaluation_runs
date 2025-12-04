import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_common(dut):
    def list2mask(lst):
        mask = 0
        for val in lst:
            if val != 0:
                mask |= (1 << val)
        return mask

    def pad_list(lst, size=8):
        return lst + [0]*(size-len(lst))
    
    # Adapted test cases (padded with zeros, first 3 lists only)
    test_cases = [
        (
            pad_list([12, 18, 23, 25, 45]), 
            pad_list([7, 12, 18, 24, 28]),
            pad_list([1, 5, 8, 12, 15, 16, 18]),
            {12, 18}
        ),
        (
            pad_list([12, 5, 23, 25, 45]),
            pad_list([7, 11, 5, 23, 28]),
            pad_list([1, 5, 8, 18, 23, 16]),
            {5, 23}
        ),
        (
            pad_list([2, 3, 4, 1]),
            pad_list([4, 5]),
            pad_list([6, 4, 8]),
            {4}
        ),
        (
            pad_list([1,2,3]),
            pad_list([4,5,6]),
            pad_list([7,8,9]),
            set()  # No common elements
        )
    ]
    
    passed = 0
    for case_idx, (l0, l1, l2, expected) in enumerate(test_cases):
        # Assign inputs
        for i in range(8):
            dut.list0[i].value = l0[i]
            dut.list1[i].value = l1[i]
            dut.list2[i].value = l2[i]
        
        await Timer(1, 'ns')
        
        # Calculate expected mask
        expected_mask = 0
        for val in expected:
            if val < 64:
                expected_mask |= (1 << val)
                
        # Verify output
        actual_value = dut.common.value.integer
        if actual_value == expected_mask:
            passed += 1
            dut._log.info(f"PASS test {case_idx}")
        else:
            found_elements = [i for i in range(64) if (actual_value >> i) & 1]
            dut._log.error(f"FAIL test {case_idx}
"
                         f"Expected: {expected}
"
                         f"Detected: {set(found_elements)}
"
                         f"Mask: 0x{actual_value:016X}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)