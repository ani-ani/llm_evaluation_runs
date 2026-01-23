import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_min_obstacles_counter(dut):
    """Test the minimum obstacles counter module"""
    
    # Create a clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst.value = 1
    dut.grid_config.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)
    
    # Test case 1: 4x4 grid with 4 obstacles (minimum pattern)
    # Place obstacles on diagonal: (0,0), (1,1), (2,2), (3,3)
    # This covers all 2x2 subgrids
    # Grid configuration: bit positions row-major
    # Row 0: bits 15-12, Row 1: bits 11-8, Row 2: bits 7-4, Row 3: bits 3-0
    # (0,0)=bit15, (1,1)=bit11, (2,2)=bit7, (3,3)=bit3
    grid1 = (1 << 15) | (1 << 11) | (1 << 7) | (1 << 3)
    dut.grid_config.value = grid1
    dut.rst.value = 0
    
    # Start computation
    # Wait for 100 cycles as specified
    for _ in range(105):
        await RisingEdge(dut.clk)
    
    # Check outputs
    if dut.valid.value != 1:
        raise TestFailure(f"valid should be 1, got {dut.valid.value}")
    
    dut._log.info(f"Test 1 - Grid with 4 obstacles: min_obstacles={dut.min_obstacles.value}, count_ways={dut.count_ways.value}")
    
    # Test case 2: Empty grid (should be invalid or detect uncovered subgrids)
    dut.grid_config.value = 0
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    for _ in range(105):
        await RisingEdge(dut.clk)
    dut._log.info(f"Test 2 - Empty grid: min_obstacles={dut.min_obstacles.value}, count_ways={dut.count_ways.value}")
    
    # Test case 3: Full grid (all 16 obstacles)
    dut.grid_config.value = 0xFFFF
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    for _ in range(105):
        await RisingEdge(dut.clk)
    dut._log.info(f"Test 3 - Full grid: min_obstacles={dut.min_obstacles.value}, count_ways={dut.count_ways.value}")
    
    # Test case 4: Single obstacle at (0,0)
    dut.grid_config.value = 1 << 15
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    for _ in range(105):
        await RisingEdge(dut.clk)
    dut._log.info(f"Test 4 - Single obstacle: min_obstacles={dut.min_obstacles.value}, count_ways={dut.count_ways.value}")
    
    # Test case 5: Checkerboard pattern
    # Alternate obstacles: 0xAAAA = 1010 1010 1010 1010
    dut.grid_config.value = 0xAAAA
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    for _ in range(105):
        await RisingEdge(dut.clk)
    dut._log.info(f"Test 5 - Checkerboard: min_obstacles={dut.min_obstacles.value}, count_ways={dut.count_ways.value}")
    
    dut._log.info("All tests completed successfully!")
