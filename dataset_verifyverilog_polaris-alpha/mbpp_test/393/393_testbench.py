import cocotb
from cocotb.triggers import Timer
@cocotb.test()
async def test_max_length(dut):
    # Test case format: (flattened_lists, list_lengths, expected_max_length, expected_max_list)
    test_cases = [
        # Test 1 (Original: [[0],[1,3],[5,7],[9,11],[13,15,17]])
        (0x0_00_00_00_00_1_3_00_00_5_7_00_00_9_B_00_00_D_F_11_00, 
         0b001_001_010_010_011, 
         3, [0x0D, 0x0F, 0x11, 0x00, 0x00]),
        
        # Test 2 (Original: [[1,2,3,4,5],[1,2,3,4],[1,2,3],[1,2],[1]])
        (0x1_00_00_00_00_1_2_3_4_00_1_2_3_00_00_1_2_00_00_00_1_00_00_00_00,
         0b001_010_011_100_101, 
         5, [0x01, 0x02, 0x03, 0x04, 0x05]),
        
        # Test 3 (Original: [[3,4,5],[6,7,8,9],[10,11,12]])
        (0x0_00_00_00_00_0_00_00_00_00_A_B_C_00_6_7_8_9_3_4_5_00_00,
         0b000_000_011_100_011, 
         4, [0x06, 0x07, 0x08, 0x09, 0x00]),
        
        # Edge case: All same length
        (0x1_2_3_00_00_4_5_6_00_00_7_8_9_00_00, 
         0b011_011_011_000_000,
         3, [0x01, 0x02, 0x03, 0x00, 0x00])
    ]
    
    passed = 0
    for idx, (flat_input, lengths, exp_len, exp_list) in enumerate(test_cases):
        dut.flattened_lists.value = flat_input
        dut.list_lengths.value = lengths
        await Timer(1, units='ns')
        
        # Check outputs
        len_ok = dut.max_length.value == exp_len
        list_ok = all(dut.max_list.value[i*5 +:5] == exp_list[i] for i in range(5))
        
        if len_ok and list_ok:
            passed += 1
            dut._log.info(f"PASS Test {idx+1}: Len={exp_len}, List={exp_list}")
        else:
            dut._log.error(f"FAIL Test {idx+1}: Got Len={dut.max_length.value} (exp {exp_len})
"
                          f"List={[int(dut.max_list.value[i*5 +:5]) for i in range(5)]}
"
                          f"Exp={exp_list}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")