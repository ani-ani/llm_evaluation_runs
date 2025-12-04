import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_char_calculator(dut):
    test_cases = [
        # Base test cases (padded with zeros)
        ("abc", "f"),
        ("gfg", "t"),
        ("ab",  "c"),
        # Edge cases
        ("zzzzzzzz", "z"),  # All z's: sum=208 → 208%26=0 → z
        ("a", "a")         # Single a: 1 → a
    ]

    passed = 0
    
    for inp_str, expected in test_cases:
        # Convert string to 64-bit packed array (pad with zeros)
        packed = 0
        for i, c in enumerate(inp_str.ljust(8, '\0')):
            packed |= ord(c) << (56 - 8*i)
            
        # Set input and wait
        dut.str_input.value = packed
        await Timer(1, units='ns')
        
        # Check output
        actual = chr(dut.result_char.value)
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: '{inp_str}' -> '{actual}'")
        else:
            dut._log.error(f"FAIL: '{inp_str}' -> '{actual}' (expected '{expected}')")
    
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")