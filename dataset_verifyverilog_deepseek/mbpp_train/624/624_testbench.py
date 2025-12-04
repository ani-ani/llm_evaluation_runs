import cocotb
from cocotb.triggers import Timer
from cocotb.utils import get_sim_time

@cocotb.test()
async def test_to_upper(dut):
    # Pad test inputs to 8 bytes with spaces
    test_cases = [
        ("person  ", "PERSON  "),
        ("final   ", "FINAL   "),
        ("Valid   ", "VALID   ")
    ]

    passed = 0
    for input_str, expected in test_cases:
        # Convert strings to 64-bit values
        input_val = int.from_bytes(input_str.encode(), byteorder="big")
        expected_val = int.from_bytes(expected.encode(), byteorder="big")

        dut.str_in.value = input_val
        await Timer(1, units="ns")  # Allow combinational logic to settle

        if dut.str_out.value == expected_val:
            passed += 1
            dut._log.info(f"PASS: '{input_str}' -> '{expected}'")
        else:
            actual_str = dut.str_out.value.buff
            dut._log.error(f"FAIL: Input '{input_str}', Output '{actual_str.decode()}', Expected '{expected}'")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")