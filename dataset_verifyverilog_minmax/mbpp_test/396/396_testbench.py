import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_start_end(dut):
    test_cases = [
        # (first, last, expected)
        ("a", "a", 1),  # Test 1 & 2 combined
        ("a", "d", 0),  # Test 3
        ("", "", 1),    # Edge: empty (handled as ASCII 0)
        ("z", "z", 1),  # Edge: same char
        ("\xFF", "\xFF", 1)  # Max ASCII
    ]
    
    passed = 0
    for first, last, expected in test_cases:
        # Convert chars to ASCII values
        first_val = ord(first) if first else 0
        last_val = ord(last) if last else 0
        
        dut.first_char.value = first_val
        dut.last_char.value = last_val
        await Timer(1, units='ns')
        
        if int(dut.match.value) == expected:
            passed += 1
            dut._log.info(f"PASS: '{chr(first_val) if first_val else 'null}' vs '{chr(last_val) if last_val else 'null}' → {expected}")
        else:
            dut._log.error(f"FAIL: '{chr(first_val)}' vs '{chr(last_val)}' → {dut.match.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")