import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_max_list(dut):
    # Test case format: (input_list, valid_lengths, expected_length, expected_list)
    test_cases = [
        ([[13,15,17,0], [0,0,0,0], [5,7,0,0], [1,3,0,0]], [3,1,2,2], 3, [13,15,17,0]),  # Adapted Test1
        ([[10,12,14,15], [5,7,0,0], [1,0,0,0], [0,0,0,0]], [4,2,1,0], 4, [10,12,14,15]),  # Adapted Test2
        ([[15,20,25,0], [5,0,0,0], [0,0,0,0], [0,0,0,0]], [3,1,0,0], 3, [15,20,25,0]),  # Adapted Test3
        ([[1,2,0,0], [3,4,5,0], [6,7,8,9], [0,0,0,0]], [2,3,4,0], 4, [6,7,8,9])  # New test
    ]
    passed = 0
    for idx, (lists, valid, exp_len, exp_list) in enumerate(test_cases):
        # Set inputs
        for i in range(4):
            dut.lists.value[i] = (lists[i][0] << 20) | (lists[i][1] << 15) | (lists[i][2] << 10) | (lists[i][3] << 5)
            dut.valid_lengths.value[i] = valid[i]
        
        await Timer(1, units='ns')
        
        # Check outputs
        max_list_out = [ (dut.max_list.value >> (20 - 5*i)) & 0x1F for i in range(4) ]
        
        if dut.max_length.value == exp_len and max_list_out == exp_list:
            passed += 1
            dut._log.info(f"PASS TC{idx+1}: LEN={dut.max_length.value} LIST={max_list_out}")
        else:
            dut._log.error(f"FAIL TC{idx+1}: Got LEN={dut.max_length.value} ({exp_len}), LIST={max_list_out} ({exp_list})")
    
    dut._log.info(f"SUMMARY: {passed}/{len(test_cases)} tests passed")