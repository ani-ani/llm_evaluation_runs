import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_longest(dut):
    # Test case format: (num_valid, [strings], [lengths], expected_str, expected_valid)
    # Strings represented as 64-bit hex: 'a' = 0x6100000000000000, 'bb'=0x6262000000000000 etc.
    test_cases = [
        (0, [0]*8, [0]*8, 0, 0),  # Empty list
        (3, [0x6100000000000000, 0x6200000000000000, 0x6300000000000000], [1,1,1]+[0]*5, 0x6100000000000000, 1),  # First of equals
        (6, [
            0x7800000000000000,        # 'x'
            0x7979790000000000,        # 'yyy'
            0x7a7a7a7a00000000,       # 'zzzz'
            0x7777770000000000,        # 'www'
            0x7a7a7a7a00000000,       # 'zzzz' again
            0x6162630000000000        # 'abc'
        ], [1,3,4,3,4,2]+[0]*2, 0x7a7a7a7a00000000, 1)  # First max at index 2
    ]
    
    passed = 0
    for tc in test_cases:
        num_valid, strings, lengths, exp_str, exp_valid = tc
        dut.num_valid.value = num_valid
        for i in range(8):
            # Pad test cases to 8 elements
            s = strings[i] if i < len(strings) else 0
            l = lengths[i] if i < len(lengths) else 0
            dut.strings[i].value = s
            dut.lengths[i].value = l
        
        await Timer(1, units='ns') # Combinational delay
        
        if dut.valid.value == exp_valid and (dut.valid.value == 0 or dut.longest_str.value == exp_str):
            passed += 1
            msg = "PASS"
        else:
            msg = "FAIL"
        
        hex_str = f"0x{dut.longest_str.value:016x}" if dut.valid.value else "None"
        dut._log.info(f"{msg}: num_valid={num_valid} got_valid={dut.valid.value} res={hex_str}
")
    
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")