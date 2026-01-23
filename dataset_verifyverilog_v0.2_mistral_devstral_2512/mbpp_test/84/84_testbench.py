import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_newman_conway(dut):
    """Test Newman-Conway sequence computation"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(25, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: n=10, expected result=6
    dut.n.value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 30 cycles)
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "done signal should be high"
    assert dut.result.value == 6, f"Expected P(10)=6, got {dut.result.value}"
    print(f"Test 1 PASSED: P(10) = {dut.result.value}")
    
    await RisingEdge(dut.clk)
    
    # Test 2: n=2, expected result=1
    dut.n.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "done signal should be high"
    assert dut.result.value == 1, f"Expected P(2)=1, got {dut.result.value}"
    print(f"Test 2 PASSED: P(2) = {dut.result.value}")
    
    await RisingEdge(dut.clk)
    
    # Test 3: n=3, expected result=2
    dut.n.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "done signal should be high"
    assert dut.result.value == 2, f"Expected P(3)=2, got {dut.result.value}"
    print(f"Test 3 PASSED: P(3) = {dut.result.value}")
    
    await RisingEdge(dut.clk)
    
    # Additional test: n=1, expected result=1
    dut.n.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "done signal should be high"
    assert dut.result.value == 1, f"Expected P(1)=1, got {dut.result.value}"
    print(f"Test 4 PASSED: P(1) = {dut.result.value}")
    
    await RisingEdge(dut.clk)
    
    # Additional test: n=5, expected result=3
    dut.n.value = 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "done signal should be high"
    assert dut.result.value == 3, f"Expected P(5)=3, got {dut.result.value}"
    print(f"Test 5 PASSED: P(5) = {dut.result.value}")
    
    print("
=== Summary: 5/5 tests passed ===")
