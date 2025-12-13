import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_handsome(dut):
    clock = Clock(dut.clk, 10, units="ns")  # 100MHz clock
    cocotb.start_soon(clock.start())
    \
    test_cases = [
        (13, [12, 14], True),  # Original sample (scaled)
        (2312, [2303], False),  # Only 2303 is closest
        (2223, [2221, 2224], True)  # Tie case
    ]
    \
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    \
    passed = 0
    for (input_val, expected, is_tie) in test_cases:
        dut.start.value = 0
        dut.num_in.value = input_val
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        \
        # Wait for valid output (max 100 cycles)
        timeout = 100
        while not dut.valid.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        \
        if dut.valid.value != 1:
            dut._log.error("Timeout on input=%d" % input_val)
            continue
        \
        # Check results
        r1 = dut.result1.value.integer
        if is_tie:
            r2 = dut.result2.value.integer
            if (r1 == expected[0] and r2 == expected[1]) or \
               (r1 == expected[1] and r2 == expected[0]):
                passed += 1
            else:
                dut._log.error(f"Input {input_val}: Got ({r1},{r2}) but expected {expected}")
        else:
            if r1 == expected[0]:
                passed += 1
            elif len(expected) > 1 and (r1 == expected[1]):
                passed += 1
            else:
                dut._log.error(f"Input {input_val}: Got {r1} but expected {expected}")
        \
        await RisingEdge(dut.clk)
    \
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)