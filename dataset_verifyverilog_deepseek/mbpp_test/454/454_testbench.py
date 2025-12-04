import cocotb
from cocotb.triggers import Timer

def str_to_bytes(s):
    # Convert string to 8-byte array with space padding
    padded = s.ljust(8, ' ')[:8]
    return int.from_bytes(padded.encode('ascii'), 'big')

@cocotb.test()
async def test_find_z(dut):
    test_cases = [
        ("pythonz.", True),   # 'z' at position 6 (0-based)
        ("xyz.    ", True),   # 'z' at position 2
        ("  lang  .", False), # No 'z'
        ("zzzzzzzz", True),   # All 'z's
        ("abcdefg ", False)   # No 'z'
    ]
    
    passed = 0
    for text, expected in test_cases:
        dut.text.value = str_to_bytes(text)
        await Timer(1, units='ns')
        result = dut.match_found.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: '{text}' => {result}")
        else:
            dut._log.error(f"FAIL: '{text}' => {result}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed}/{total} test cases"