import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_remove_odd(dut):
    test_cases = [
        ("python", "yhn", 3),  # 6 chars -> 3
        ("program", "rga", 3),  # 7 chars -> 3
        ("language", "agae", 4),  # 8 chars -> 4
        ("a", "", 0)  # Edge case: 1 char -> 0
    ]

    passed = 0
    for inp, expected, exp_len in test_cases:
        # Convert input to ASCII bytes with zero-padding
        inp_padded = [ord(c) if i < len(inp) else 0 for i, c in enumerate(inp.ljust(8, '\\0'))]
        
        # Apply inputs
        for i in range(8):
            dut.str_in[i].value = inp_padded[i]
        
        await Timer(1, 'ns')
        
        # Check output
        out_str = ''.join([chr(dut.str_out[i].value.integer) for i in range(4) if i < exp_len])
        
        if out_str == expected and dut.out_len.value == exp_len:
            passed += 1
            dut._log.info(f"PASS: '{inp}' -> '{out_str}' (len:{exp_len})")
        else:
            dut._log.error(f"FAIL: '{inp}' -> '{out_str}' (len:{dut.out_len.value}), expected '{expected}' (len:{exp_len})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")