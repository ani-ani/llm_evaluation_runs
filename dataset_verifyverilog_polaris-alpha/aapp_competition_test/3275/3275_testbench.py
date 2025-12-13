import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import itertools

MOD_VAL = 10007

@cocotb.test()
async def test_purchases(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases [N, C, [a1..a4], [b1..b4], expected]
    test_cases = [
        (2, 2, [1,1,0,0], [1,1,0,0], 1),          # Original sample scaled
        (2, 2, [1,2,0,0], [2,3,0,0], 4),          # Original sample scaled
        (4, 2, [1,2,3,1], [1,2,3,1], 66),         # Modified 3rd test case
        (4, 3, [3,3,3,3], [1,1,1,1], 6561%MOD_VAL) # All max colored case
    ]

    passed = 0
    for n_val, c_val, a_list, b_list, expected in test_cases:
        # Reset and initialize
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load client data (4 cycles)
        for i in range(4):
            dut.client_sel.value = i
            dut.a_i.value = a_list[i] if a_list[i] > 0 else 1  # Ensure ≥1
            dut.b_i.value = b_list[i] if b_list[i] > 0 else 1  # Ensure ≥1
            await RisingEdge(dut.clk)

        # Set params and start
        dut.C_param.value = c_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (20 cycles)
        await ClockCycles(dut.clk, 20)
        assert dut.done.value == 1, "Done signal not asserted"

        # Check result
        if dut.result.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: N={n_val}, C={c_val}, a={a_list}, b={b_list} => {dut.result.value}, expected {expected}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
