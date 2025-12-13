import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_swap(dut):
    # Test format: (size, input_array_as_list, expected_output_as_list)
    test_cases = [
        (5, [12,35,9,56,24,0,0,0], [24,35,9,56,12,0,0,0]), # Original Test 1
        (3, [1,2,3,0,0,0,0,0], [3,2,1,0,0,0,0,0]),        # Original Test 2
        (3, [4,5,6,0,0,0,0,0], [6,5,4,0,0,0,0,0]),        # Original Test 3
        (1, [10,0,0,0,0,0,0,0], [10,0,0,0,0,0,0,0]),      # Edge case: single element
        (8, [1,2,3,4,5,6,7,8], [8,2,3,4,5,6,7,1])        # Edge case: full array swap
    ]
    passed = 0
    for size, arr_in, expected_arr in test_cases:
        # Pack input array to 64-bit value
        packed_in = 0
        for i in range(8):
            packed_in |= (arr_in[i] & 0xFF) << (i*8)
        
        # Pack expected output
        packed_exp = 0
        for i in range(8):
            packed_exp |= (expected_arr[i] & 0xFF) << (i*8)
        
        # Apply test vectors
        dut.size.value = size
        dut.array_in.value = packed_in
        await Timer(1, units='ns')
        
        # Check results
        if dut.array_out.value == packed_exp:
            passed += 1
            dut._log.info(f"PASS: Size={size} Input={arr_in} Received={dut.array_out.value.integer.to_bytes(8,'big')}")
        else:
            received = [int((dut.array_out.value >> (i*8)) & 0xFF) for i in range(8)]
            dut._log.error(f"FAIL: Size={size} Input={arr_in}
  Expected={expected_arr}
  Received={received}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")