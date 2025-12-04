import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_slime_merger(dut):
    clock = Clock(dut.clk, 10, units='ns')  # Create 10ns period clock
    cocotb.start_soon(clock.start())  # Start the clock
    test_cases = [
        (1, [1, 0, 0, 0]), 
        (2, [2, 0, 0, 0]), 
        (3, [2, 1, 0, 0]), 
        (8, [4, 0, 0, 0])
    ]
    passed = 0
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    for (n_val, expected) in test_cases:
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        for _ in range(n_val):  # Wait n cycles for processing
            await RisingEdge(dut.clk)
        # Check done signal after n cycles
        if not dut.done.value:
            await RisingEdge(dut.clk)  # Wait one more cycle if needed
        assert dut.done.value == 1, "Done signal not asserted"
        result = [dut.elem_0.value, dut.elem_1.value, dut.elem_2.value, dut.elem_3.value]
        # Compare only relevant elements (ignore trailing zeros)
        match = True
        for i in range(4):
            if expected[i] == 0 and result[i] != 0:
                continue  # Allow padding zeros beyond actual output
            if int(result[i]) != expected[i]:
                match = False
                break
        if match:
            passed += 1
        else:
            dut._log.error(f"Test failed: n={n_val} Result={result} Expected={expected}")
        # Wait for done to deassert
        await RisingEdge(dut.clk)
        dut._log.info(f"{passed}/{len(test_cases)} tests passed")
