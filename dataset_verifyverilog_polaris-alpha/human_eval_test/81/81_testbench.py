import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_gpa_converter(dut):
    # Convert test cases to scaled integers and encoded outputs
    # Format: (scaled_gpa, expected_code)
    test_cases = [
        (40, 0b00000),  # 4.0 → A+
        (30, 0b00011),  # 3.0 → B+
        (17, 0b00111),  # 1.7 → C
        (20, 0b00110),  # 2.0 → C+
        (35, 0b00010),  # 3.5 → A-
        (12, 0b01001),  # 1.2 → D+
        (5,  0b01011),  # 0.5 → D-
        (0,  0b01100),  # 0.0 → E
        (10, 0b01001),  # 1.0 → D+
        (3,  0b01011),  # 0.3 → D-
        (15, 0b01000),  # 1.5 → C-
        (28, 0b00011),  # 2.8 → B+
        (33, 0b00010)   # 3.3 → A-
    ]

    passed = 0
    for gpa, expected in test_cases:
        dut.scaled_gpa.value = gpa
        await Timer(1, units='ns')
        result = dut.letter_code.value
        if int(result) == expected:
            passed += 1
            dut._log.info(f"PASS: {gpa/10.0} → {bin(expected)}")
        else:
            dut._log.error(f"FAIL: {gpa/10.0} → got {bin(int(result))}, expected {bin(expected)}")
    
    total = len(test_cases)
    dut._log.info(f"Test summary: {passed}/{total} passed")
    assert passed == total