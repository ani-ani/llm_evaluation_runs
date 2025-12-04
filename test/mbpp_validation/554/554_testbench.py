import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_filter_odds(dut):
    test_cases = [
        ([1,2,3,4,5,6,0,0], [1,3,5,0,0,0,0,0], 0b0010101),
        ([10,11,12,13,0,0,0,0], [11,13,0,0,0,0,0,0], 0b0000011),
        ([7,8,9,1,0,0,0,0], [7,9,1,0,0,0,0,0], 0b0000111),
        ([2,4,6,8,0,0,0,0], [0,0,0,0,0,0,0,0], 0b0000000),
        ([255,1,3,5,7,9,11,13], [255,1,3,5,7,9,11,13], 0b11111111)
    ]

    passed = 0
    for i, (din, expected_res, expected_mask) in enumerate(test_cases):
        for idx in range(8):
            dut.data[idx].value = din[idx]
        await Timer(1, units='ns')
        
        res_match = all(dut.result[idx].value == expected_res[idx] for idx in range(8))
        mask_match = dut.valid_mask.value == expected_mask
        
        if res_match and mask_match:
            passed += 1
            dut._log.info(f"Test {i+1} PASS")
        else:
            dut._log.error(f"Test {i+1} FAIL
Input: {din}
Result: {[dut.result[idx].value for idx in range(8)]}
Expected: {expected_res}
Valid mask: {bin(dut.valid_mask.value)} vs expected {bin(expected_mask)}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")