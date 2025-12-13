import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_dog_walk(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Simple line segments (expected distance=10)
    shadow_x = [0<<16, 10<<16, 0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    shadow_y = [0<<16, 0<<16, 0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    lydia_x = [30<<16, 15<<16,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    lydia_y = [0<<16, 0<<16,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    
    # Load input data
    dut.shadow_segment_count.value = 1
    dut.lydia_segment_count.value = 1
    for i in range(16):
        dut.shadow_x[i].value = shadow_x[i]
        dut.shadow_y[i].value = shadow_y[i]
        dut.lydia_x[i].value = lydia_x[i]
        dut.lydia_y[i].value = lydia_y[i]
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 3500 cycles)
    for _ in range(3500):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    # Check result (expected 10.0 in Q16.16 = 655360)
    expected = int(10.0 * (1<<16))
    assert dut.min_distance.value == expected, f"Test 1 failed: {dut.min_distance.value} != {expected}"
    
    # Test case 2: Simple diagonal paths (expected distance = sqrt(2) ≈ 1.414213)
    shadow_x = [0]*16
    shadow_y = [0]*16
    lydia_x = [0]*16
    lydia_y = [0]*16
    shadow_x[0] = 10<<16; shadow_y[0] = 0<<16
    shadow_x[1] = 10<<16; shadow_y[1] = 8<<16
    lydia_x[0] = 9<<16; lydia_y[0] = 0<<16
    lydia_x[1] = 9<<16; lydia_y[1] = 8<<16
    
    dut.shadow_segment_count.value = 1
    dut.lydia_segment_count.value = 1
    for i in range(16):
        dut.shadow_x[i].value = shadow_x[i]
        dut.shadow_y[i].value = shadow_y[i]
        dut.lydia_x[i].value = lydia_x[i]
        dut.lydia_y[i].value = lydia_y[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(3500):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    expected_sqrt2 = int(1.414213562373 * (1<<16))
    tolerance = int(0.0001 * (1<<16))  # Absolute error < 0.0001
    assert abs(dut.min_distance.value.signed_integer - expected_sqrt2) <= tolerance, 
        f"Test 2 failed: {dut.min_distance.value} not within tolerance of {expected_sqrt2}"
    
    dut._log.info("2/2 tests passed")
