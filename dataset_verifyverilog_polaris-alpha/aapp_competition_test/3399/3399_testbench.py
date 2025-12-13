import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_lang_divider(dut):
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())
    \
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    \
    test_cases = [
        # Test1: Valid pattern (3x4 grid from sample - padded to 4x4)
        {
            "n": 3, "m": 4,
            "grid": [
                0b0010_0010_0001_0001,  # Row1: 2211 (padded with 0s)
                0b0001_0001_0001_0010,  # Row2: 1112
                0b0001_0001_0001_0010,  # Row3: 1112
                0b0000_0000_0000_0000   # Row4 (unused)
            ],
            "expect_impossible": 0,
            "expected_a": 0b1111_0001_0000_0000,  # A pattern
            "expected_b": 0b1100_1111_0011_0000,
            "expected_c": 0b0000_0000_0011_1111
        },
        # Test2: Impossible (1x1 grid)
        {
            "n": 1, "m": 1,
            "grid": [0b0001],  # Single '1' cell
            "expect_impossible": 1
        }
    ]
    \
    passed = 0
    for case in test_cases:
        # Setup inputs
        dut.n.value = case["n"]
        dut.m.value = case["m"]
        dut.grid_data.value = case["grid"][0]  # Single row for flattened data
        \
        # Start pulse
        dut.start.value = 1
        await ClockCycles(dut.clk, 3)  # Wait 3 cycles for computation
        dut.start.value = 0
        \
        # Check outputs
        if case["expect_impossible"]:
            if dut.impossible_flag.value == 1:
                passed += 1
            else:
                dut._log.error("Failed impossible case")
        else:
            if (dut.lang_a.value == case["expected_a"] and \
                dut.lang_b.value == case["expected_b"] and \
                dut.lang_c.value == case["expected_c"] and \
                dut.impossible_flag.value == 0):
                passed += 1
            else:
                dut._log.error(f"Test failed: Got A={dut.lang_a.value}, B={dut.lang_b.value}, C={dut.lang_c.value}
)
    \
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
