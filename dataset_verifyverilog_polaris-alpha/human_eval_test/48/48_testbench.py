import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_palindrome(dut):
    test_cases = [
        (b'\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00', True),  # Empty (all zeros)
        (b'aba\\x00\\x00\\x00\\x00\\x00', True),         # 'aba'
        (b'aaaaa\\x00\\x00\\x00', True),                # 'aaaaa'
        (b'zbcd\\x00\\x00\\x00\\x00', False),           # 'zbcd'
        (b'xywyx\\x00\\x00\\x00', True),               # 'xywyx'
        (b'xywyz\\x00\\x00\\x00', False),              # 'xywyz'
        (b'xywzx\\x00\\x00\\x00', False)               # 'xywzx'
    ]
    passed = 0
    for i, (text_bytes, expected) in enumerate(test_cases):
        # Convert bytes to 64-bit integer
        value = int.from_bytes(text_bytes, byteorder='big')
        dut.text.value = value
        await Timer(1, 'ns')
        actual = dut.is_pal.value
        if actual == expected:
            passed += 1
            dut._log.info(f"Test {i} PASS: {text_bytes} -> {actual}")
        else:
            dut._log.error(f"Test {i} FAIL: {text_bytes} -> {actual}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")