import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_flip_case(dut):
    def str_to_bits(s):
        s = s.ljust(16, '\\x00')[:16]  # Pad/truncate to 16 chars
        return int.from_bytes(s.encode(), 'little')

    def flip_char(c):
        if ord('A') <= ord(c) <= ord('Z'):
            return chr(ord(c) ^ 0x20)
        elif ord('a') <= ord(c) <= ord('z'):
            return chr(ord(c) ^ 0x20)
        return c

    test_cases = [
        ('', ''),  # Empty string (all zeros)
        ('Hello!', 'hELLO!'),
        ('These violent d', 'tHESE VIOLENT D')
    ]
    
    passed = 0
    for input_str, expected_str in test_cases:
        dut.string_in.value = str_to_bits(input_str)
        await Timer(1, units='ns')
        output_bits = dut.string_out.value.integer
        output_str = output_bits.to_bytes(16, 'little').decode().rstrip('\\x00')
        expected_str_padded = expected_str.ljust(16, '\\x00')[:16]
        
        success = all(flip_char(c1) == c2 
            for c1, c2 in zip(input_str.ljust(16, '\\x00'), expected_str_padded))
        
        if success:
            passed += 1
            dut._log.info(f"PASS: '{input_str}' => '{output_str.strip('\\x00')}'")
        else:
            dut._log.error(f"FAIL: Input '{input_str}'
       Got '{output_str.strip('\\x00')}'
  Expected '{expected_str}'")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")