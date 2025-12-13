import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_zero_ratio(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    def fp_convert(val):
        return int(val * 256)

    test_cases = [
        # (input_array, expected_ratio, expect_error)
        ([0, 1, 2, -1, -5, 6, 0, -3], 2/6 * 256, False),   # Scaled-down original Test1
        ([1,2,3,4,5,6,7,8], 0, False),                     # Original Test2/3
        ([0,0,0,0,0,0,0,1], 7/1 * 256, False),            # Edge case
        ([0,0,0,0,0,0,0,0], 0, True)                      # Error case
    ]

    await reset()
    passed = 0

    for array, exp_ratio, exp_error in test_cases:
        # Load array
        for i in range(8):
            dut.array[i].value = array[i]

        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait 9 cycles (8 elements + 1 division)
        await ClockCycles(dut.clk, 9)

        # Check outputs
        if exp_error:
            if dut.error.value == 1:
                passed += 1
            else:
                dut._log.error(f"FAIL: Error flag not set for all-zero array")
        else:
            actual = dut.ratio.value.integer
            # Allow 2 LSB error tolerance
            if abs(actual - exp_ratio) <= 2 and dut.done.value == 1:
                passed += 1
            else:
                dut._log.error(f"FAIL: Input={array} Got: {actual/256:.4f} (0x{actual:04X})"
                              f" Expected: {exp_ratio/256:.4f} (0x{int(exp_ratio):04X})")

    dut._log.info(f"RESULT: {passed}/{len(test_cases)} tests passed")
