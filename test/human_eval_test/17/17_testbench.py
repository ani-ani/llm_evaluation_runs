import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_music_parser(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    # Test cases in (input_str, expected_beats) format
    test_cases = [
        ("", []),
        ("o o o o", [4,4,4,4]),
        (".| .| .| .|", [1,1,1,1]),
        ("o| o| .| .| o o o o", [2,2,1,1,4,4,4,4]),
        ("o| .| o| .| o o| o o|", [2,1,2,1,4,2,4,2])
    ]

    passed = 0
    total = len(test_cases)
    await reset()

    for input_str, expected in test_cases:
        # Prepare padded 32-byte input
        padded = input_str.ljust(32, '\\0')
        packed = int.from_bytes(padded.encode('utf-8'), 'little')
        length = len(input_str)

        dut.music_string.value = packed
        dut.length.value = length
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        result_beats = []
        timeout = 128
        while (dut.done.value == 0 and timeout > 0):
            if dut.beat_valid.value == 1:
                result_beats.append(dut.beat.value.integer)
            await RisingEdge(dut.clk)
            timeout -= 1

        if timeout == 0:
            dut._log.error(f"Test '{input_str}': Timeout waiting for done")
        elif result_beats == expected:
            dut._log.info(f"PASS: '{input_str}' → {result_beats}")
            passed += 1
        else:
            dut._log.error(f"FAIL: '{input_str}'
  Got {result_beats}
  Exp {expected}")
        await RisingEdge(dut.clk)  # Extra cycle between tests

    dut._log.info(f"{passed}/{total} tests passed")