import cocotb
from cocotb.triggers import Timer
@cocotb.test()
async def test_replace_spaces(dut):
    def string_to_vector(s):
        padded = s.ljust(32, '\\0')
        return int.from_bytes(padded.encode('ascii'), 'big')
    
    def vector_to_string(vec):
        bytes_val = vec.to_bytes(32, 'big')
        return bytes_val.decode('ascii').rstrip('\\0')
    
    test_cases = [
        ("hello people", '@', "hello@people"),
        ("python program language", '$', "python$program$language"),
        ("blank space", '-', "blank-space"),
        ("                ", '*', "****************"),  # 16 spaces
        ("no_spaces", '_', "no_spaces")  # Edge case
    ]
    
    passed = 0
    for str_in, char_in, expected in test_cases:
        vec_in = string_to_vector(str_in)
        vec_expected = string_to_vector(expected)
        
        dut.str_in.value = vec_in
        dut.char_in.value = ord(char_in)
        await Timer(1, units='ns')
        
        result = vector_to_string(dut.str_out.value)
        if dut.str_out.value == vec_expected:
            passed += 1
            dut._log.info(f"PASS: '{str_in}' -> '{result}'")
        else:
            actual_str = vector_to_string(dut.str_out.value)
            dut._log.error(f"FAIL: Input='{str_in}' (char: '{char_in}')" + 
                          f" Expected='{expected}' ({vec_expected:x})" + 
                          f" Actual='{actual_str}' ({dut.str_out.value:x})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")