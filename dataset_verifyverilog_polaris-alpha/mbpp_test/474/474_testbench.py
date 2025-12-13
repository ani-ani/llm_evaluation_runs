import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_char_replacer(dut):
    test_cases = [
        # Test 1: Basic replacement
        (
            b"polygon".ljust(16, b'\\0'),  # Original string
            ord('y'),                       # ASCII 'y'
            ord('l'),                       # Replacement 'l'
            b"pollgon".ljust(16, b'\\0')     # Expected result
        ),
        # Test 2: Multiple replacements
        (
            b"character",
            ord('c'),
            ord('a'),
            b"aharaater"
        ),
        # Test 3: No replacement needed
        (
            b"python",
            ord('l'),
            ord('a'),
            b"python"
        ),
        # Additional test: Full 16-byte string
        (
            b"hello_world12345",
            ord('l'),
            ord('x'),
            b"hexlo_worxd12345"
        )
    ]

    passed = 0
    for orig, ch, newch, expected in test_cases:
        # Pad test cases to 16 bytes
        orig_padded = orig.ljust(16, b'\\0')
        expected_padded = expected.ljust(16, b'\\0')

        # Convert to integers for Verilog
        str_in_val = int.from_bytes(orig_padded, byteorder='big')
        expected_val = int.from_bytes(expected_padded, byteorder='big')

        # Apply inputs
        dut.str_in.value = str_in_val
        dut.ch.value = ch
        dut.newch.value = newch
        await Timer(1, units='ns')

        # Check output
        actual_val = dut.str_out.value.integer
        if actual_val == expected_val:
            passed += 1
            dut._log.info(f"PASS: {orig} -> {expected} (replaced {chr(ch)}->{chr(newch)})")
        else:
            actual_bytes = actual_val.to_bytes(16, 'big').rstrip(b'\\0')
            dut._log.error(f"FAIL: Input={orig}, ch={chr(ch)}, newch={chr(newch)}")
            dut._log.error(f"     Expected: {expected_val:x} ({expected_padded})")
            dut._log.error(f"     Actual:   {actual_val:x} ({actual_bytes})")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"