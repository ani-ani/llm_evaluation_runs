import cocotb
from cocotb.triggers import Timer
from cocotb.binary import BinaryValue

@cocotb.test()
async def test_string_filter(dut):
    def str_to_bits(s, width=8):
        # Convert string to 64-bit ASCII representation
        padded = s.ljust(width, '\\0')
        return int.from_bytes(padded.encode(), byteorder='big')
    
    def create_test_vector(strings):
        # Pack 4 strings into 256-bit value
        vec = 0
        for s in reversed(strings):  # strings[3] at MSB, strings[0] at LSB
            vec = (vec << 64) | str_to_bits(s)
        return vec
    
    test_cases = [
        # (input_strings, prefix, prefix_len, expected_mask)
        ([], "xxx", 3, 0),  # Empty case
        (["abc\\0\\0\\0\\0", "bcd\\0\\0\\0\\0", "cde\\0\\0\\0\\0", "array\\0\\0"], "a", 1, 0b1001),
        (["xxx\\0\\0\\0\\0", "asd\\0\\0\\0\\0", "xxy\\0\\0\\0\\0", "xxxAAA\\0"], "xxx", 3, 0b1001),
        (["John\\0\\0\\0\\0", "Jane\\0\\0\\0\\0", "Doe\\0\\0\\0\\0", "Smith"], "", 0, 0b1111),
        (["apple\\0\\0", "applet\\0\\0", "orange", "app"], "app", 3, 0b1101)
    ]
    
    passed = 0
    for strings_in, pref, plen, expected in test_cases:
        # Pad input to 4 elements
        padded_strings = (strings_in + ["\\0\\0\\0\\0\\0\\0\\0"] * 4)[:4]
        vec = create_test_vector(padded_strings)
        prefix_val = str_to_bits(pref)
        
        dut.strings_flat.value = vec
        dut.prefix.value = prefix_val
        dut.prefix_len.value = plen
        
        await Timer(1, 'ns')
        
        actual = dut.match_mask.value.integer
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {strings_in} -> {bin(expected)}")
        else:
            dut._log.error(f"FAIL: {strings_in} Expected {bin(expected)} Got {bin(actual)}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")