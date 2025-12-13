import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_word_splitter(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases: (input_text, expected_output)
    test_cases = [
        ("Hello world!  ", 2),    # 14 chars: 2 words (original test)
        ("Hello,world!", 2),      # 12 chars: 2 words (comma split)
        ("abcdef", 3),           # 6 chars: 'b'(1), 'd'(3), 'f'(5) => 3
        ("aaabb", 2),            # 5 chars: 'b'(1), 'b'(1) => 2
        ("aaaBb", 1),            # 5 chars: 'b'(1) => 1 (capital ignored)
        ("", 0)                  # empty string
    ]

    passed = 0
    for text, expected in test_cases:
        # Pad text to 16 bytes with nulls
        padded = text.ljust(16, '\0')
        text_bits = int.from_bytes(padded.encode('ascii'), 'big')

        # Apply input
        dut.text_in.value = text_bits
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check result
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: '{text}' => {dut.result.value}")
        else:
            dut._log.error(f"FAIL: '{text}' => {dut.result.value}, expected {expected}")
        
        # Wait 1 cycle between tests
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")