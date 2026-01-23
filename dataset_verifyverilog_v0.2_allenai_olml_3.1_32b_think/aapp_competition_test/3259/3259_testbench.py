import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

async def perform_update(dut, L, R, A, B):
    dut.op_type.value = 0
    dut.L.value = L
    dut.R.value = R
    dut.A.value = A
    dut.B.value = B
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)

async def perform_query(dut, L, R):
    dut.op_type.value = 1
    dut.L.value = L
    dut.R.value = R
    dut.A.value = 0
    dut.B.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    return dut.result.value

@cocotb.test()
async def test_aladin_box_sim(dut):
    """Test the Aladin Box Simulator"""
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.op_type.value = 0
    dut.L.value = 0
    dut.R.value = 0
    dut.A.value = 0
    dut.B.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Starting Tests")
    
    # Test 1: Update boxes 0-5 with A=1, B=2 (Values: 1%2=1, 2%2=0, 3%2=1, 4%2=0, 5%2=1, 6%2=0)
    # Expected sum of 0-5: 1+0+1+0+1+0 = 3
    await perform_update(dut, 0, 5, 1, 2)
    res = await perform_query(dut, 0, 5)
    if res != 3:
        raise TestFailure(f"Test 1 Failed: Expected sum 3, got {res}")
    dut._log.info("Test 1 Passed: Update 0-5 A=1 B=2, Query Sum=3")
    
    # Test 2: Update boxes 0-3 with A=3, B=4
    # Box 0: 1*3 % 4 = 3
    # Box 1: 2*3 % 4 = 6 % 4 = 2
    # Box 2: 3*3 % 4 = 9 % 4 = 1
    # Box 3: 4*3 % 4 = 12 % 4 = 0
    # Sum 0-3: 3+2+1+0 = 6
    await perform_update(dut, 0, 3, 3, 4)
    res = await perform_query(dut, 0, 3)
    if res != 6:
        raise TestFailure(f"Test 2 Failed: Expected sum 6, got {res}")
    dut._log.info("Test 2 Passed: Update 0-3 A=3 B=4, Query Sum=6")
    
    # Test 3: Query partial range from previous update (Box 1 and 2)
    # Expected: 2 + 1 = 3
    res = await perform_query(dut, 1, 2)
    if res != 3:
        raise TestFailure(f"Test 3 Failed: Expected sum 3, got {res}")
    dut._log.info("Test 3 Passed: Query 1-2, Sum=3")
    
    # Test 4: Update box 7 (single element)
    # L=7, R=7, A=10, B=3 -> (7-7+1)*10 = 10 % 3 = 1
    await perform_update(dut, 7, 7, 10, 3)
    res = await perform_query(dut, 7, 7)
    if res != 1:
        raise TestFailure(f"Test 4 Failed: Expected 1, got {res}")
    dut._log.info("Test 4 Passed: Single element update")
    
    # Test 5: Verify other boxes are unaffected
    # Box 0 is still 3 (from Test 2)
    res = await perform_query(dut, 0, 0)
    if res != 3:
        raise TestFailure(f"Test 5 Failed: Expected 3, got {res}")
    dut._log.info("Test 5 Passed: Check isolation")
    
    dut._log.info("All 5 tests passed!")