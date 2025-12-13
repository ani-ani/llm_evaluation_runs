import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_all_chars_same(dut):
    test_cases = [
        # (input_string, len, expected)
        ("python", 6, 0),
        ("aaa", 3, 1),
        ("data", 4, 0),
        ("a", 1, 1),
        ("aaaaaaa", 7, 1),
        ("abcdabcd", 8, 0)
    ]
    
    passed = 0
    for s_str, input_len, expected in test_cases:
        # Pad string to 8 characters with null bytes
        padded_str = s_str.ljust(8, '\\x00')
        
        # Convert string to 64-bit value
        s_val = 0
        for char in padded_str:
            s_val = (s_val << 8) | ord(char)
        
        # Apply inputs
        dut.s.value = s_val
        dut.len.value = input_len
        
        # Wait for combinational logic to settle
        await Timer(1, units='ns')
        
        # Check output
        if dut.all_same.value == expected:
            passed += 1
            dut._log.info(f"PASS: '{s_str[:8]}' len={input_len} => {dut.all_same.value}")
        else:
            dut._log.error(f"FAIL: '{s_str[:8]}' len={input_len} => {dut.all_same.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")