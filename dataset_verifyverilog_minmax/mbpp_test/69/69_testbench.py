import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_sublist(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (main_list, sub_list, expected)
    tests = [
        ([2,4,3,5,7,0,0,0], [3,7,0,0], 0),  # Original test 1
        ([2,4,3,5,7,0,0,0], [4,3,0,0], 1),  # Original test 2
        ([2,4,3,5,7,0,0,0], [1,6,0,0], 0),  # Original test 3
        ([0,0,0,0,0,0,0,0], [0,0,0,0], 1),  # All-zero sublist case
        ([8,15,23,42,0,0,0,0], [23,42,0,0], 1)  # Additional test
    ]

    passed = 0
    for main, sub, expected in tests:
        # Load inputs
        for i, val in enumerate(main):
            dut.main_list[i].value = val
        for i, val in enumerate(sub):
            dut.sub_list[i].value = val

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        for _ in range(8):
            await RisingEdge(dut.clk)

        # Check result
        if dut.done.value == 1:
            if dut.found.value == expected:
                cocotb.log.info(f"PASS: {main} vs {sub} = {dut.found.value}")
                passed += 1
            else:
                cocotb.log.error(f"FAIL: {main} vs {sub} = {dut.found.value}, expected {expected}")
        else:
            cocotb.log.error("TIMEOUT: Done signal not asserted")

    cocotb.log.info(f"Test summary: {passed}/{len(tests)} tests passed")