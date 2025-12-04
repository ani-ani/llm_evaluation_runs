import cocotb
from cocotb.triggers import Timer

def str_to_bin(s):
    padded = s.ljust(16, '\\\\0')  # Pad strings to 16 chars
    return int.from_bytes(padded.encode(), byteorder='little')

def process_ref(s):
    return s.replace(' ', '#').replace('_', ' ').replace('#', '_').ljust(16, '\\\\0')

@cocotb.test()
async def test_replace(dut):
    test_cases = [
        ('Jumanji The Jungle', 'Jumanji_The_Jungle'),
        ('The_Avengers', 'The Avengers'),
        ('Fast and Furious', 'Fast_and_Furious'),
        ('a_b c_d', 'a b c d'),  # Edge case with multiple replacements
        ('NoChangesHere!', 'NoChangesHere!')  # No modifications
    ]
    
    passed = 0
    for inp_str, exp_str in test_cases:
        full_inp = inp_str.ljust(16, '\\\\0')
        full_exp = exp_str.ljust(16, '\\\\0')
        
        dut.text_in.value = str_to_bin(full_inp)
        await Timer(1, units='ns')
        
        out_bytes = dut.text_out.value.to_bytes(16, byteorder='little')
        result = out_bytes.decode(errors='ignore').rstrip('\\\\0')
        
        if result == exp_str:
            passed += 1
            dut._log.info(f"PASS: '{inp_str}' -> '{exp_str}'")
        else:
            dut._log.error(f"FAIL: '{inp_str}' -> '{result}', expected '{exp_str}'")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")