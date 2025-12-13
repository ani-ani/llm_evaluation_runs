import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_toggle(dut):
    # Test cases extended to 8 chars (pad with spaces)
    test_cases = [
        ("Python  ", "pYTHON  "),
        ("Pangram ", "pANGRAM "),
        ("LIttLE  ", "liTTle  "),
        ("1234AaZz", "1234aAzZ"),  # Edge case: mixed + numbers
        ("        ", "        ")    # Edge case: spaces
    ]
    
    passed = 0
    for input_str, expected in test_cases:
        # Convert strings to packed bytes
        input_bytes = int.from_bytes(input_str.encode("ascii"), "little")
        expected_bytes = int.from_bytes(expected.encode("ascii"), "little")
        
        dut.str_in.value = input_bytes
        await Timer(1, "ns")
        
        if dut.str_out.value == expected_bytes:
            passed += 1
            dut._log.info(f"PASS: '{input_str}' -> '{expected}'")
        else:
            actual_str = bytes.fromhex(f"{int(dut.str_out.value):016x}").decode("ascii")
            dut._log.error(f"FAIL: '{input_str}' -> '{actual_str}' (expected '{expected}')")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")