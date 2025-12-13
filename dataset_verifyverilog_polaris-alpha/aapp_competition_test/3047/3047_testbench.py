import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_puzzle(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test case 1 (scaled version of sample input 1):
    # Input representation ("_" = 255):
    # Salamander: [_, 90], [_, 40] → Top: [255,90], Bottom: [255,40]
    # Golem: [6,_], [12,_] → Top: [6,255], Bottom: [12,255]
    # Expected: 1 solution
    test_cases = [
        (
            [255, 90, 6, 255, 255, 255],  # burger [S,Y,G]
            [255, 255, 255, 255, 255, 255],  # slop (S,Y,G)
            [255, 255, 255, 255, 255, 255],  # sushi (S,Y,G)
            [40, 255, 255, 255, 12, 255],   # drumstick (S,Y,G)
            1, 0  # expected_count, many_flag
        ),
        # Test case 2 (trivial solution):
        (
            [1,1,1, 1,1,1],  # no missing values
            [2,2,2, 2,2,2],
            [3,3,3, 3,3,3],
            [6,6,6, 6,6,6],  # all ratios 1/2 = 3/6 ⇒ consistent
            1, 0
        ),
        # Test case 3 (multiple solutions):
        # Salamander burger missing, all others fixed
        # burger_s * 40 = 90 * ??? (free variable) "many" condition
        (
            [255, 90, 6, 6,6,6],
            [90, 90, 6,6,6,6],
            [40,40,2,2,2,2],
            [40,40,4,4,4,4], # burger_s * 40 = 90*?
            0, 1  # many_flag should assert
        )
    ]

    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for case in test_cases:
        # Unpack test case
        (burger, slop, sushi, drumstick, exp_count, exp_many) = case
        # Load inputs
        for i in range(6):
            dut.burger[i].value = burger[i]
            dut.slop[i].value = slop[i]
        for i in range(6):
            dut.sushi[i].value = sushi[i]
            dut.drumstick[i].value = drumstick[i]
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        # Check outputs
        if (dut.num_solutions.value == exp_count) and (dut.many_flag.value == exp_many):
            passed += 1
        else:
            dut._log.error(
                f"Test failed: Got {dut.num_solutions.value}/many={dut.many_flag.value} " +
                f"Expected {exp_count}/many={exp_many}"
            )
        # Reset for next test case
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
