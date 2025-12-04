import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import binascii

@cocotb.test()
async def test_replacer(dut):
    # Generate 10ns period clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    test_cases = [
        ("My Name is Dawood", "My%20Name%20is%20Dawood"),
        ("I am a Programmer", "I%20am%20a%20Programmer"),
        ("I love Coding", "I%20love%20Coding"),
        ("     ", "%20%20%20%20%20"),  # Edge case: all spaces
        ("", "")  # Edge case: empty
    ]

    passed = 0

    # Pad inputs to 16 characters
    padded_cases = [
        (s.ljust(16, \\0), expected.ljust(16*3 if s.count(" ") > 0 else 16, \\0))
        for s, expected in test_cases
    ]

    for (input_str, expected) in padded_cases:
        # Convert strings to bytes
        in_bytes = input_str.encode("ascii")
        expected_bytes = expected.encode("ascii")

        # Apply reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Setup input
        dut.in_str.value = int.from_bytes(in_bytes, "little")
        dut.start.value = 1

        # Wait for processing
        for _ in range(16):
            await RisingEdge(dut.clk)
            dut.start.value = 0  # Only assert start once

        # Check done signal
        assert dut.done.value == 1, "done signal not asserted after time"

        # Extract output bytes
        out_bytes = dut.out_str.value.buff
        actual = out_bytes[0:len(expected_bytes)]

        # Validate
        if actual == expected_bytes:
            passed += 1
            dut._log.info(f"PASS: Input '{input_str}' -> '{expected}'")
        else:
            hex_actual = binascii.hexlify(actual).decode()
            hex_expected = binascii.hexlify(expected_bytes).decode()
            dut._log.error(f"FAIL: '{input_str}' => {hex_actual} != expected {hex_expected}")

        # Cycle between tests
        await RisingEdge(dut.clk)
        dut.done.value = 0

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")