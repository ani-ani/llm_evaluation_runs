import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_even_filter(dut):
    test_cases = [
        # (input_str, length, expected, expected_len)
        # 'abcdef' -> 'ace'
        (b'abcdef\\x00\\x00', 6, b'ace\\x00\\x00\\x00', 3),
        # 'python' -> 'pto'
        (b'python\\x00\\x00', 6, b'pto\\x00\\x00\\x00', 3),
        # 'data' -> 'dt'
        (b'data\\x00\\x00\\x00\\x00', 4, b'dt\\x00\\x00\\x00\\x00\\x00', 2),
        # 'lambs' -> 'lms'
        (b'lambs\\x00\\x00\\x00', 5, b'lms\\x00\\x00\\x00\\x00', 3),
        # Edge case: empty string
        (b'\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00', 0, b'\\x00'*8, 0),
        # Max length
        (b'12345678', 8, b'1357\\x00\\x00\\x00\\x00', 4)
    ]

    passed = 0
    for (inp_str, inp_len, exp_str, exp_len) in test_cases:
        # Convert bytes to integer
        inp_val = int.from_bytes(inp_str, byteorder='little')
        exp_val = int.from_bytes(exp_str, byteorder='little')
        
        dut.input_str.value = inp_val
        dut.str_length.value = inp_len
        await Timer(1, units='ns')
        
        filtered_bytes = dut.filtered_str.value.buff
        out_len = dut.out_length.value

        # Check filtered string
        if filtered_bytes != exp_val:
            dut._log.error(f"FAIL: Input={bytes(filtered_bytes)} Length={out_len}, Expected {bytes(exp_val)} Len={exp_len}")
        else:
            if out_len != exp_len:
                dut._log.error(f"FAIL: Wrong length {out_len}, expected {exp_len}")
            else:
                passed += 1
                dut._log.info(f"PASS: {inp_str[:inp_len]} → {exp_str[:exp_len]}")
    
    dut._log.info(f"SUMMARY: Passed {passed}/{len(test_cases)} tests")
    assert passed == len(test_cases)