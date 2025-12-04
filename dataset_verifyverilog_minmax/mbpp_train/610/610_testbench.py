import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_remover(dut):
    # Define test cases (input_array, k, expected_output)
    test_cases = [
        # Test 1
        ([1,1,2,3,4,4,5,1]+[0]*8, 3, [1,1,3,4,4,5,1]+[0]*9),
        # Test 2
        ([0,0,1,2,3,4,4,5,6,6,6,7,8,9,4,4], 4, [0,0,1,3,4,4,5,6,6,6,7,8,9,4,4,4]),
        # Test 3
        ([10,10,15,19,18,18,17,26,26,17,18,10]+[0]*4, 5, [10,10,15,19,18,17,26,26,17,18,10]+[0]*5),
        # Edge case: k=1 (remove first)
        ([5,4,3,2,1]+[0]*11, 1, [4,3,2,1]+[0]*12),
        # Edge case: k>16 (no removal)
        ([9,8,7]+[0]*13, 17, [9,8,7]+[0]*13)
    ]
    
    passed = 0
    for test in test_cases:
        # Convert inputs to bit vectors
        inp_array, k, expected = test
        
        # Format input array to 80-bit value (16x5-bit)
        input_val = 0
        for i, val in enumerate(inp_array):
            input_val |= (val & 0x1F) << (i*5)
        
        # Format expected output
        expected_val = 0
        for i, val in enumerate(expected):
            expected_val |= (val & 0x1F) << (i*5)
        
        dut.array_in.value = input_val
        dut.k.value = k
        await Timer(1, 'ns')
        
        result = dut.array_out.value.integer
        if result == expected_val:
            passed += 1
            dut._log.info(f"PASS: k={k} (input: {inp_array[:16]}, output: {hex(result)})")
        else:
            # Decode output for better debugging
            decoded = [(result >> (i*5)) & 0x1F for i in range(16)]
            dut._log.error(f"FAIL: k={k} Input={inp_array}
  Expected={expected}
  Got={decoded}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")