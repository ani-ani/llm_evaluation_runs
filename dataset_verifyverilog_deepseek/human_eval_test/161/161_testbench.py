import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_case_reverse(dut):
    test_cases = [
        # (input_str, expected_output)
        ("AsDf    ", "aSdF    "),  # Pad to 8 chars with spaces
        ("1234    ", "    4321"),  # No letters -> reversed
        ("ab      ", "AB      "),
        ("#a@C    ", "#A@c    "),
        ("#6@2    ", "    2@6#"),
        ("#$a^D   ", "#$A^d   "),
        ("#ccc    ", "#CCC    ")
    ]

    passed = 0
    for inp, exp in test_cases:
        # Convert strings to 64-bit integers
        inp_val = int.from_bytes(inp.encode('ascii'), 'big')
        exp_val = int.from_bytes(exp.encode('ascii'), 'big')

        dut.str_in.value = inp_val
        await Timer(1, units='ns')

        if dut.str_out.value == exp_val:
            passed += 1
            dut._log.info(f"PASS: '{inp}' -> '{exp}'")
        else:
            actual = dut.str_out.value.integer.to_bytes(8, 'big').decode('ascii').rstrip()
            dut._log.error(f"FAIL: '{inp}' -> '{actual}', expected '{exp}'")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")