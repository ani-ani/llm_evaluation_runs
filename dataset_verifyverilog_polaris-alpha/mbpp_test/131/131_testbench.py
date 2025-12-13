import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_reverse_vowels(dut):
    test_cases = [
        (6, [ord('P'), ord('y'), ord('t'), ord('h'), ord('o'), ord('n') + [0]*2], 
            [ord('P'), ord('y'), ord('t'), ord('h'), ord('o'), ord('n')]),
        (3, [ord('U'), ord('S'), ord('A')] + [0]*5, 
            [ord('A'), ord('S'), ord('U')] + [0]*5),
        (2, [ord('a'), ord('b')] + [0]*6, 
            [ord('a'), ord('b')] + [0]*6),
        (8, [ord('a'), ord('b'), ord('E'), ord('d'), ord('i'), ord('f'), ord('O'), ord('h')], 
            [ord('O'), ord('b'), ord('i'), ord('d'), ord('E'), ord('f'), ord('a'), ord('h')])
    ]
    
    passed = 0
    for length, input_chars, expected in test_cases:
        dut.string_length.value = length
        for i in range(8):
            dut.chars_in[i].value = input_chars[i]
        await Timer(1, units='ns')
        
        match = True
        for i in range(8):
            if i < length:
                if dut.chars_out[i].value != expected[i]:
                    match = False
            else:
                if dut.chars_out[i].value != 0:
                    match = False
        
        if match:
            passed += 1
            dut._log.info(f"PASS: Length={length} Input='{''.join(chr(c) for c in input_chars[:length])}'")
        else:
            actual = ''.join(chr(dut.chars_out[i].value) for i in range(length))
            exp_str = ''.join(chr(c) for c in expected[:length])
            dut._log.error(f"FAIL: Length={length} Input='{''.join(chr(c) for c in input_chars[:length])}' Output='{actual}' Expected='{exp_str}'")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")