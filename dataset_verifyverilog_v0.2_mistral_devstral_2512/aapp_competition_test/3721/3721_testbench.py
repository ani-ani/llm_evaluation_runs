import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_chemical_table(dut):
    """Test Chemical Table Fusion Logic"""
    # Clock generation (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.n.value = 0
    dut.m.value = 0
    dut.q.value = 0
    dut.r.value = 0
    dut.c.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Example 1 (2x2, 3 elements -> 0)
    dut.n.value = 2
    dut.m.value = 2
    dut.q.value = 3
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    inputs_1 = [(1, 2), (2, 2), (2, 1)] # 1-based input
    for r, c in inputs_1:
        # Wait for rden if implemented, else simple delay
        await RisingEdge(dut.clk)
        dut.valid_in.value = 1
        dut.r.value = r - 1
        dut.c.value = c - 1
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        # Wait for internal processing
        for _ in range(50): 
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
    
    # Wait for final done
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 0, f"Test 1 failed: expected 0, got {dut.result.value}"
    print("Test 1 passed (2x2, 3 elems -> 0)")

    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: Example 2 (1x5, 3 elements -> 2)
    dut.n.value = 1
    dut.m.value = 5
    dut.q.value = 3
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    inputs_2 = [(1, 3), (1, 1), (1, 5)]
    for r, c in inputs_2:
        await RisingEdge(dut.clk)
        dut.valid_in.value = 1
        dut.r.value = r - 1
        dut.c.value = c - 1
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        for _ in range(50):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
        
    assert dut.result.value == 2, f"Test 2 failed: expected 2, got {dut.result.value}"
    print("Test 2 passed (1x5, 3 elems -> 2)")

    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 3: Example 3 (4x3, 6 elements -> 1)
    dut.n.value = 4
    dut.m.value = 3
    dut.q.value = 6
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    inputs_3 = [(1, 2), (1, 3), (2, 2), (2, 3), (3, 1), (3, 3)]
    for r, c in inputs_3:
        await RisingEdge(dut.clk)
        dut.valid_in.value = 1
        dut.r.value = r - 1
        dut.c.value = c - 1
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        for _ in range(50):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
        
    assert dut.result.value == 1, f"Test 3 failed: expected 1, got {dut.result.value}"
    print("Test 3 passed (4x3, 6 elems -> 1)")

    print("All tests passed!")