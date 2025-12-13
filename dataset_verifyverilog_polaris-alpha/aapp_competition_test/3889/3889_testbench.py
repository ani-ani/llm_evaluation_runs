import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_puppy_recolor(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Define test cases (input_string, expected_output)
    tests = [
        ("aabddc", 1),   # Scaled to 6 chars - original example Yes
        ("abc", 0),      # 3 unique chars - No
        ("jjj", 1),      # All same - Yes
        ("a", 1),        # Single char - Yes
        ("abcdefghijklmnop", 0),  # 16 unique chars - No
        ("fnfvn", 1),    # Contains duplicates - Yes
        ("ba", 0),       # 2 unique chars - No
        ("aa", 1),       # Duplicates - Yes
        ("/x00", 0)       # Invalid handling (non-lowercase)
    ]

    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for s, expected in tests:
        # Format string input to 16-byte packed format
        packed = 0
        valid_len = len(s)
        for i, c in enumerate(s):
            packed |= ord(c) << (8 * (15-i))

        # Apply inputs
        dut.valid_length.value = valid_len
        dut.string_in.value = packed
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)

        # Verify outputs
        if dut.result.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: Input '{s}' Expected {expected} Got {dut.result.value}")

    dut._log.info(f"Test summary: {passed}/{len(tests)} passed")