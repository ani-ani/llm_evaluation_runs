import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_boredom_counter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        # (input_string, expected_count)
        ("Hello world\0\0\0\0\0", 0),   # Original Test 1
        ("Is the sky blue?\0", 0),       # Original Test 2
        ("I love It !\0\0\0\0\0\0", 1), # Original Test 3
        ("bIt\0\0\0\0\0\0\0\0\0\0\0\0\0", 0), # Original Test 4
        ("I am.I too!\0\0\0\0\0", 2),  # Modified Test - 2 boredoms
        ("You and I\0\0\0\0\0\0\0\0", 0) # Original Test 6
    ]

    passed = 0
    for input_str, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Prepare input
        str_len = len(input_str.rstrip("\0"))
        for i in range(16):
            char = ord(input_str[i]) if i < len(input_str) else 0
            dut.str_data[i].value = char
        dut.str_len.value = str_len

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait 16 cycles for processing
        for _ in range(16):
            await RisingEdge(dut.clk)

        # Verify output
        if dut.done.value == 1 and dut.count.value == expected:
            passed += 1
            dut._log.info(f"PASS: '{input_str}' -> {expected}")
        else:
            dut._log.error(f"FAIL: '{input_str}' -> {dut.count.value}, expected {expected}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)