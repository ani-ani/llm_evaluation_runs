import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_boomerang(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    async def reset():"""
        await RisingEdge(dut.clk)"""
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    await reset()
    
    # Test case 1: n=6 :: 2 0 3 0 1 1 (convert to n=6, indexes 0-5)
    a_values = [2,0,3,0,1,1]
    expected_targets = [(1,1),(1,6),(2,3),(2,5),(3,5)]
    
    # Setup inputs
    dut.start.value = 0
    dut.n.value = 6
    for i in range(8):
        if i < 6:
            dut.__dict__[f"a_{i}"].value = a_values[i]
        else:
            dut.__dict__[f"a_{i}"].value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Verify outputs
    assert dut.failed.value == 0, "Test 1 failed: Expected valid solution"
    assert dut.valid.value == 1, "Test 1 failed: Valid signal not asserted"
    
    # Gather all output targets
    t_count = 0
    targets = []
    while len(targets) < len(expected_targets):
        if dut.t_valid.value:
            r = dut.t_row.value.integer
            c = dut.t_col.value.integer
            # Ensure 0-based indexing matches original format
            targets.append((r,c))
        await RisingEdge(dut.clk)
    
    # Compare targets (order not enforced)
    for t in expected_targets:
        (er, ec) = t
        found = any(r == er and c == ec for (r, c) in targets)
        assert found, f"Test 1 missing target {er},{ec}"
    
    # Test case 2: n=1 :: [0] (no targets)
    await reset()
    dut.n.value = 1
    dut.a_0.value = 0
    for i in range(1,8):
        dut.__dict__[f"a_{i}"].value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.failed.value == 0, "Test 2 failed: Expected valid solution"
    assert dut.valid.value == 1, "Test 2 valid not set"
    assert dut.t_valid.value == 0, "Test 2 unexpected target"
    
    # Test case 3: Impossible case (6 inputs with invalid config)
    await reset()
    impossible_case = [3,2,2,2,1,1]
    dut.n.value = 6
    for i in range(8):
        if i < 6:
            dut.__dict__[f"a_{i}"].value = impossible_case[i]
        else:
            dut.__dict__[f"a_{i}"].value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.failed.value == 1, "Test 3 failed: Expected detection of impossible configuration"
    
    dut._log.info("3/3 tests passed")