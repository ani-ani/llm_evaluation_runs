import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_max_zebra(dut):
    # Test cases: (input_string, data_len, expected_output)
    test_cases = [
        ("bwwwbwwbw", 9, 5),
        ("bwwbwwb", 7, 3),
        ("bwb", 3, 3),
        ("b", 1, 1),
        ("wbwb", 4, 4),
        ("wb", 2, 2)
    ]

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for s, length, expected in test_cases:
        dut.start.value = 0
        dut.data_len.value = length
        
        # Convert string to bit vector (0='b', 1='w')
        bit_vector = 0
        for i, char in enumerate(s):
            if char == 'w':
                bit_vector |= (1 << i)
        dut.data_in.value = bit_vector

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Verify output
        if dut.max_streak.value == expected:
            passed += 1
        else:
            dut._log.error("Test failed: %s (len=%d) got %d, expected %d" % (s, length, dut.max_streak.value, expected))
        
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)