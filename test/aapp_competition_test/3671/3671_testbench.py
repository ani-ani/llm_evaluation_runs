import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_job_scheduler(dut):
    # Generate clock (100MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1

    # Test cases with job counts and times (pre-sorted)
    test_cases = [
        (4, [10000, 400000, 500000, 900000], 12),
        (5, [8, 10, 2, 1000000, 30556926000], 12),
        (4, [100000, 400000, 400000, 700000], 10),
        (3, [0, 400001, 800002], 12),  # Min spacing
        (2, [0, 400000], 8)            # Max case
    ]

    # Reset the module
    await reset()

    passed = 0
    for (n, times, expected) in test_cases:
        # Pad arrays to 8 elements
        padded_times = times + [0]*(8 - len(times))
        
        # Apply inputs
        dut.job_count.value = n
        for i in range(8):
            dut.job_times[i].value = padded_times[i]
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await ClockCycles(dut.clk, 80)
        
        # Check results
        if dut.done.value == 1 and dut.total_cookies.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: N={n}, times={times}, got={dut.total_cookies.value}, expected={expected}")
        
        # Wait a few cycles between tests
        await ClockCycles(dut.clk, 5)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")