import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_splitter(dut):
    # Test case format: (input_list, L, (expected_part1, expected_part2))
    # Convert lists to flat array representation
    test_cases = [
        # Test 1: Original [1,1,2,3,4,4,5,1] with L=3
        (0x0101020304040501, 3, (0x0101020000000000, 0x0304040501000000)),
        
        # Test 2: Original ['a','b','c','d'] (ASCII 0x61-0x64) with L=2
        (0x6162636400000000, 2, (0x6162000000000000, 0x6364000000000000)),
        
        # Test 3: Original ['p','y','t','h','o','n'] with L=4
        (0x707974686F6E0000, 4, (0x7079746800000000, 0x6F6E000000000000))
    ]
    
    passed = 0
    for flat_in, L_val, (exp1, exp2) in test_cases:
        dut.flat_array.value = flat_in
        dut.L.value = L_val
        await Timer(1, units='ns')
        
        result1 = dut.part1.value.integer
        result2 = dut.part2.value.integer
        
        if result1 == exp1 and result2 == exp2:
            passed += 1
            dut._log.info(f"PASS: L={L_val} got ({hex(result1)}, {hex(result2)})")
        else:
            dut._log.error(f"FAIL: L={L_val} got ({hex(result1)}, {hex(result2)}). Expected ({hex(exp1)}, {hex(exp2)})")
    
    dut._log.info(f"RESULT: {passed}/{len(test_cases)} tests passed")