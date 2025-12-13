import cocotb
from cocotb.triggers import Timer

def str_to_bin(s, max_len=8):
    # Convert string to 64-bit left-aligned ASCII value
    val = 0
    for i, c in enumerate(s[:max_len]):
        val |= ord(c) << (8*(7-i))
    return val

@cocotb.test()
async def test_substring_counter(dut):
    test_cases = [
        # Format: (main_str, sub_str, expected_count)
        ('', 'x', 0),
        ('xyxyxyx', 'x', 4),       # Main_len=7, sub_len=1
        ('cacacacac', 'cac', 4),  # Main_len=9 → clipped to 8
        ('john doe', 'john', 1)
    ]
    
    passed = 0
    for main_str, sub_str, expected in test_cases:
        # Convert strings to 64-bit values
        dut.main_str.value = str_to_bin(main_str)
        dut.sub_str.value = str_to_bin(sub_str)
        dut.main_len.value = min(len(main_str), 8)
        dut.sub_len.value = min(len(sub_str), 8)
        
        await Timer(1, units='ns')
        
        if dut.count.value == expected:
            passed += 1
            dut._log.info(f"PASS: '{main_str}'/'{sub_str}' → {expected}")
        else:
            dut._log.error(f"FAIL: '{main_str}'/'{sub_str}' → {dut.count.value}, expected {expected}")
    
    # Test edge cases
    dut.main_str.value = str_to_bin('aaaa')
    dut.sub_str.value = str_to_bin('aa')
    dut.main_len.value = 4
    dut.sub_len.value = 2
    await Timer(1, units='ns')
    if dut.count.value == 3:
        passed += 1
        dut._log.info("PASS: 'aaaa'/'aa' → 3")
    else:
        dut._log.error(f"FAIL: 'aaaa'/'aa' → {dut.count.value}, expected 3")
    
    total_tests = len(test_cases) + 1
    dut._log.info(f"{passed}/{total_tests} tests passed")
    assert passed == total_tests