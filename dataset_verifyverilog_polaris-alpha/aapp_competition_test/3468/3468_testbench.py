import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_app_installer(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Should install 2 apps (Sample 1 - scaled)
    dut.c.value = 100
    dut.d1.value = 99; dut.s1.value = 1  # App 1
    dut.d2.value = 1;  dut.s2.value = 99  # App 2
    # Set all other d/s to 0
    for i in range(3,9):
        getattr(dut, f'd{i}').value = 0
        getattr(dut, f's{i}').value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (12 cycles)
    await ClockCycles(dut.clk, 15)
    assert dut.done.value == 1, "Test 1 completion not signaled"
    assert dut.max_count.value == 2, f"Test1 count {dut.max_count.value} != 2"
    assert dut.order[0].value == 1, f"Test1 order[0]={dut.order[0].value} !=1"
    assert dut.order[1].value == 2, f"Test1 order[1]={dut.order[1].value} !=2"
    
    # Test Case 2: Should install none (Sample 2 - scaled)
    dut.c.value = 100
    dut.d1.value = 500; dut.s1.value = 1  # Exceeds capacity
    dut.d2.value = 1;  dut.s2.value = 500  # Exceeds capacity
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await ClockCycles(dut.clk, 15)
    assert dut.done.value == 1, "Test2 completion not signaled"
    assert dut.max_count.value == 0, f"Test2 count {dut.max_count.value} !=0"
    
    # Test Case 3: Max space edge case (use all 1024MB)
    dut.c.value = 1023
    # 8 apps requiring exactly max(1,127) each (126 storage ea)
    for i in range(1,9):
        getattr(dut, f'd{i}').value = 1
        getattr(dut, f's{i}').value = 127  # Need 128 space initially
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await ClockCycles(dut.clk, 15)
    assert dut.done.value == 1, "Test3 completion not signaled"
    # Expected installed apps: floor(1023/(max(1,127))) = 7 apps (1023//128=7)
    assert dut.max_count.value == 7, f"Test3 count={dut.max_count.value} !=7"
    
    dut._log.info("3/3 tests passed")