import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_hex_prime_counter(dut):
    """Test hex prime digit counter with scaled test cases"""
    
    def str_to_val(s):
        """Convert string to (len, hex_str)"""
        hex_map = {c: int(c,16) for c in "0123456789ABCDEF"}
        full_len = 32
        len_val = len(s)
        
        # Convert characters and pad with zeros
        bits = []
        for c in s.ljust(full_len, '0'):
            bits.append(hex_map[c])
        
        # Pack into single 128-bit value (first char in MSB)
        packed = 0
        for i, val in enumerate(bits):
            packed = (packed << 4) | val
        return (len_val, packed)
    
    # Adapted test cases
    test_cases = [
        ("", 0),
        ("AB", 1),    # B is prime (11)
        ("1077E", 2), # digits 7,7
        ("ABED1A33", 4), # B,D,3,3
        ("2020", 2),   # 2,2
        ("123456789ABCDEF0", 6), # 2,3,5,7,B,D
        ("112233445566778899AABBCCDDEEFF00", 12) # 2*6 + 3*2 + 5*2 + 7*2
    ]
    
    passed = 0
    for s, expected in test_cases:
        len_val, packed = str_to_val(s)
        dut.len.value = len_val
        dut.hex_str.value = packed
        await Timer(1, units='ns')
        actual = dut.count.value.integer
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: '{s}' -> {expected}")
        else:
            dut._log.error(f"FAIL: '{s}' got {actual}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)