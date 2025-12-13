import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_rect_intersect(dut):
    # Adapted test cases (max 4 rectangles, smaller coordinates):
    # Case 1: 3 rectangles with overlap (expect 1)
    test1 = [ (0,0,3,3), (2,2,5,5), (10,10,12,12) ]  # Rect 0 & 1 overlap
    # Case 2: 4 rectangles without overlaps (expect 0)
    test2 = [ (0,0,5,5), (6,6,10,10), (3,10,8,15), (1,20,4,25) ]
    # Case 3: Edge case - exactly adjacent but not overlapping (expect 0)
    test3 = [ (0,0,2,2), (2,0,4,2) ]   # x meet at 2
    # Case 4: Zero area rectangle (invalid per spec but good test)
    # (x1 < x2 and y1 < y2 enforced in challenge)
    test_cases = [ (test1,1), (test2,0), (test3,0) ]

    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for rect_list, expected in test_cases:
        # Reset and load rectangles
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.load.value = 1
        for (x1,y1,x2,y2) in rect_list:
            dut.x1.value = x1
            dut.y1.value = y1
            dut.x2.value = x2
            dut.y2.value = y2
            await RisingEdge(dut.clk)
        dut.load.value = 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        # Check result
        if dut.result.value == expected:
            passed += 1
        else:
            dut._log.error("Test failed: Expected %d got %d (rectangles: %s)" % (expected, dut.result.value, str(rect_list)))
        await RisingEdge(dut.clk)
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
