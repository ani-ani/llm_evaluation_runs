import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_pancake(dut):
    # Clock generator
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (original + edge cases)
    test_cases = [
        ([15, 79, 25, 38, 69, 0, 0, 0], [0, 0, 0, 15, 25, 38, 69, 79]),
        ([98, 12, 54, 36, 85, 0, 0, 0], [0, 0, 0, 12, 36, 54, 85, 98]),
        ([41, 42, 32, 12, 23, 0, 0, 0], [0, 0, 0, 12, 23, 32, 41, 42]),
        ([8,7,6,5,4,3,2,1], [1,2,3,4,5,6,7,8]),
        ([255,128,64,32,16,8,4,2], [2,4,8,16,32,64,128,255])
    ]

    passed = 0
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for input_arr, expected in test_cases:
        # Load input
        for i in range(8):
            dut.data_in[i].value = input_arr[i]

        # Start sorting
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Verify output
        result = [dut.sorted[i].value.integer for i in range(8)]
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {input_arr} -> {result}")
        else:
            dut._log.error(f"FAIL: {input_arr} -> {result}, expected {expected}")

        await RisingEdge(dut.clk)

    dut._log.info(f"Test Summary: {passed}/{len(test_cases)} passed")