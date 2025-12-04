import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_vacation(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (scaled to 16 days max)
    test_cases = [
        (4, [1,3,2,0], 2), # Original test 1
        (7, [1,3,3,2,1,2,3], 0), # Original test 2
        (2, [2,2], 1), # Original test 3
        (1, [0], 1), # Single rest day
        (3, [3,3,3], 0) # Full activity days
    ]

    passed = 0
    for (n, days, expected) in test_cases:
        # Load inputs
        dut.num_days.value = n
        for i in range(16):
            if i < len(days):
                dut.day_status[i].value = days[i] if i < len(days) else 0
            else:
                dut.day_status[i].value = 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break

        # Verify output
        if dut.rest_count.value != expected:
            dut._log.error(f"Test failed: {days} gave {dut.rest_count.value}, expected {expected}")
        else:
            passed += 1

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    if passed != len(test_cases):
        raise TestFailure("Some tests failed")