import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def vote_optimizer_test(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    async def reset_dut():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1

    def to_q88(f):
        return int(f * 256)

    # Test cases (adapted for v <=8)
    test_cases = [
        (2, 2, [to_q88(0.5)], [1], 2),  # Original sample 1
        (4, 3, [to_q88(1.0), to_q88(0.4)], [11, 1], 3)  # Original sample 2
    ]

    passed = 0
    for idx, (k, v_in, p_list, b_list, expected) in enumerate(test_cases):
        # Apply reset
        await reset_dut()

        # Populate inputs (pad unused voters with 0)
        dut.v.value = v_in
        for i in range(7):
            if i < len(p_list):
                dut.p_i[i].value = p_list[i]
                dut.b_i[i].value = b_list[i]
            else:
                dut.p_i[i].value = 0
                dut.b_i[i].value = 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check result (mask for k bits)
        result = dut.b_v.value & ((1 << k) - 1)
        if result == expected:
            passed += 1
            dut._log.info(f"Test {idx} passed: {result} == {expected}")
        else:
            dut._log.error(f"Test {idx} FAILED: Got {result}, expected {expected}")

        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)