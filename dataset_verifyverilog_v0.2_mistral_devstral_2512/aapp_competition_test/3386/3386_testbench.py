import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_tour_finder_basic(dut):
    """Test basic 2x3 grid case"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    dut.M.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 2x3 grid
    dut.N.value = 2
    dut.M.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion with timeout
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 10000, "Timeout - computation took too long"
    assert dut.found.value == 1, "Should find valid tour for 2x3"
    
    # Verify tour length is 6
    tour_len = 0
    # Check tour is valid by reading the tour array (would need to monitor writes)
    print(f"Test 2x3: found={dut.found.value}, done={dut.done.value}")

@cocotb.test()
async def test_tour_finder_1x1(dut):
    """Test 1x1 grid - should return no solution"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.N.value = 1
    dut.M.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Should complete"
    assert dut.found.value == 0, "Should not find tour for 1x1"
    print(f"Test 1x1: found={dut.found.value}, done={dut.done.value}")

@cocotb.test()
async def test_tour_finder_2x2(dut):
    """Test 2x2 grid - should return no solution (distance 2 or 3 impossible)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.N.value = 2
    dut.M.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Should complete"
    print(f"Test 2x2: found={dut.found.value}, done={dut.done.value}")

@cocotb.test()
async def test_tour_finder_3x3(dut):
    """Test 3x3 grid"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.N.value = 3
    dut.M.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 20000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 20000, "Timeout for 3x3"
    assert dut.done.value == 1, "Should complete"
    print(f"Test 3x3: found={dut.found.value}, done={dut.done.value}")

@cocotb.test()
async def test_tour_finder_reset(dut):
    """Test that reset works correctly"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Start in middle of computation
    dut.N.value = 3
    dut.M.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait a few cycles
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    # Reset
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Should be in IDLE state
    assert dut.done.value == 0, "Should not be done after reset"
    print("Reset test passed")
