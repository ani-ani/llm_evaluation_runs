import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

async def load_photo(dut, idx, a, b):
    """Load a single photo's time window"""
    dut.photo_idx.value = idx
    dut.a_i.value = a
    dut.b_i.value = b
    dut.load.value = 1
    await RisingEdge(dut.clk)
    dut.load.value = 0

async def reset_dut(dut):
    """Reset the DUT"""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load.value = 0
    dut.n.value = 0
    dut.t.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_photo_scheduler_basic(dut):
    """Test basic case from sample input 1: 2 photos, t=10, windows (0,15) and (5,20)"""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Load photo 0: window (0, 15)
    await load_photo(dut, 0, 0, 15)
    # Load photo 1: window (5, 20)
    await load_photo(dut, 1, 5, 20)
    
    # Set parameters
    dut.n.value = 2
    dut.t.value = 10
    await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (allow enough cycles for sorting and processing)
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.result.value == 1, f"Expected result=1 (yes), got {dut.result.value}"
    print("Test 1: 2 photos, t=10, (0,15),(5,20) -> yes")

@cocotb.test()
async def test_photo_scheduler_conflict(dut):
    """Test conflict case from sample input 2: 2 photos, t=10, windows (1,15) and (0,20)"""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Load photo 0: window (1, 15)
    await load_photo(dut, 0, 1, 15)
    # Load photo 1: window (0, 20)
    await load_photo(dut, 1, 0, 20)
    
    dut.n.value = 2
    dut.t.value = 10
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.result.value == 0, f"Expected result=0 (no), got {dut.result.value}"
    print("Test 2: 2 photos, t=10, (1,15),(0,20) -> no")

@cocotb.test()
async def test_photo_scheduler_flexible(dut):
    """Test case from sample input 3: 2 photos, t=10, windows (5,30) and (10,20)"""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Load photo 0: window (5, 30)
    await load_photo(dut, 0, 5, 30)
    # Load photo 1: window (10, 20)
    await load_photo(dut, 1, 10, 20)
    
    dut.n.value = 2
    dut.t.value = 10
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.result.value == 1, f"Expected result=1 (yes), got {dut.result.value}"
    print("Test 3: 2 photos, t=10, (5,30),(10,20) -> yes")

@cocotb.test()
async def test_photo_scheduler_single_photo(dut):
    """Test single photo that fits"""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    await load_photo(dut, 0, 100, 200)
    
    dut.n.value = 1
    dut.t.value = 50
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.result.value == 1, f"Expected result=1, got {dut.result.value}"
    print("Test 4: 1 photo, t=50, (100,200) -> yes")

@cocotb.test()
async def test_photo_scheduler_exact_deadline(dut):
    """Test photo that finishes exactly at deadline"""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Photo 0: can start at 0, must finish by 20
    await load_photo(dut, 0, 0, 20)
    # Photo 1: can start at 10, must finish by 30
    await load_photo(dut, 1, 10, 30)
    
    dut.n.value = 2
    dut.t.value = 10
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.result.value == 1, f"Expected result=1, got {dut.result.value}"
    print("Test 5: Exact deadline case -> yes")